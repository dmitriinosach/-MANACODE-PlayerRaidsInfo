package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"charm.land/bubbles/v2/progress"
	"charm.land/bubbles/v2/spinner"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

var (
	dataBase = "https://gitlab.com/dmitrii.nosach/ManacodePlayerRaidsInfo/-/raw/data/"
	zipPass  = ""
)

const releaseAPI = "https://gitlab.com/api/v4/projects/dmitrii.nosach%2FManacodePlayerRaidsInfo/releases/permalink/latest"

const (
	mainFile    = "Data.lua"
	archiveDir  = "Manacode_PlayerRaidsInfo_Archive"
	archiveToc  = "Manacode_PlayerRaidsInfo_Archive.toc"
	configFile  = "updater.json"
	addonSVName = "Manacode_PlayerRaidsInfo.lua"
)

type fileInfo struct {
	Name   string `json:"name"`
	Season int    `json:"season"`
	Count  int    `json:"count"`
	Bytes  int64  `json:"bytes"`
	Zip    string `json:"zip"`
	ZipLen int64  `json:"zipBytes"`
}

type index struct {
	V        int        `json:"v"`
	Baked    string     `json:"baked"`
	Season   int        `json:"season"`
	Seasons  []int      `json:"seasons"`
	Complete bool       `json:"complete"`
	Count    int        `json:"count"`
	Files    []fileInfo `json:"files"`
}

type config struct {
	SeasonsFrom *int  `json:"seasonsFrom,omitempty"`
	Seasons     []int `json:"seasons"`
}

type localMeta struct {
	Baked    string
	Count    int
	Complete bool
	Seasons  map[int]int
}

var (
	gold   = lipgloss.Color("#ffd100")
	white  = lipgloss.Color("#f2f2f2")
	grey   = lipgloss.Color("#9d9d9d")
	dim    = lipgloss.Color("#6b6f76")
	green  = lipgloss.Color("#3ddc84")
	red    = lipgloss.Color("#ff5f56")
	purple = lipgloss.Color("#a335ee")
	edge   = lipgloss.Color("#6d5a33")
	sTitle = lipgloss.NewStyle().Foreground(gold).Bold(true)
	sLabel = lipgloss.NewStyle().Foreground(grey)
	sDim   = lipgloss.NewStyle().Foreground(dim)
	sVal   = lipgloss.NewStyle().Foreground(white).Bold(true)
	sPlus  = lipgloss.NewStyle().Foreground(green).Bold(true)
	sErr   = lipgloss.NewStyle().Foreground(red)
	sBox   = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(edge).Padding(0, 2).Width(72)
	sBtn   = lipgloss.NewStyle().Foreground(grey).Padding(0, 2).Border(lipgloss.RoundedBorder()).BorderForeground(dim)
	sBtnOn = lipgloss.NewStyle().Foreground(gold).Bold(true).Padding(0, 2).Border(lipgloss.RoundedBorder()).BorderForeground(gold)
)

type stage int

const (
	stLoading stage = iota
	stChoose
	stDownload
	stDone
	stError
)

type indexMsg struct {
	idx *index
	err error
}

type doneMsg struct {
	err     error
	written []string
}

type tickMsg time.Time

type counter struct {
	got   atomic.Int64
	total atomic.Int64
	file  atomic.Value
}

type model struct {
	dir      string
	cfg      config
	fromGame map[int]bool
	idx      *index
	before   localMeta
	after    localMeta
	stage    stage
	err      error
	cursor   int
	choices  []int
	sel      map[int]bool
	release  *releaseMsg
	btn      int
	spin     spinner.Model
	bar      progress.Model
	cnt      *counter
	written  []string
	started  time.Time
	took     time.Duration
}

func main() {
	dir, err := exeDir()
	if err != nil {
		fmt.Println("ОШИБКА:", err)
		return
	}
	m := &model{
		dir:  dir,
		spin: spinner.New(spinner.WithSpinner(spinner.MiniDot), spinner.WithStyle(lipgloss.NewStyle().Foreground(gold))),
		bar:  progress.New(progress.WithColors(purple, gold), progress.WithWidth(52), progress.WithoutPercentage()),
		cnt:  &counter{},
	}
	m.cfg = loadConfig(dir)
	m.fromGame = seasonsFromGame(dir)
	m.before = readLocal(dir)
	if len(os.Args) > 2 && os.Args[1] == "-from" {
		from, err := strconv.Atoi(os.Args[2])
		if err != nil {
			fmt.Println("ОШИБКА: -from N")
			return
		}
		msg := fetchIndex().(indexMsg)
		if msg.err != nil {
			fmt.Println("ОШИБКА:", msg.err)
			os.Exit(1)
		}
		sel := map[int]bool{}
		for s := msg.idx.Season; s >= from; s-- {
			sel[s] = true
		}
		written, err := download(*msg.idx, dir, sel, m.cnt)
		if err != nil {
			fmt.Println("ОШИБКА:", err)
			os.Exit(1)
		}
		a := readLocal(dir)
		fmt.Printf("записано: %s\nвыгрузка %s, игроков %d, полная %t, сезоны %v\n", strings.Join(written, ", "), a.Baked, a.Count, a.Complete, a.Seasons)
		return
	}
	if _, err := tea.NewProgram(m).Run(); err != nil {
		fmt.Println("ОШИБКА:", err)
		fmt.Print("Нажмите Enter, чтобы закрыть...")
		_, _ = fmt.Scanln()
	}
}

func (m *model) Init() tea.Cmd { return tea.Batch(fetchIndex, fetchRelease(m.dir), m.spin.Tick) }

type releaseMsg struct {
	tag   string
	url   string
	local string
	newer bool
}

var reVersion = regexp.MustCompile(`(?m)^## Version:\s*(\S+)`)

var reDigits = regexp.MustCompile(`\d+`)

func verNum(s string) []int {
	var out []int
	for _, part := range reDigits.FindAllString(s, -1) {
		v, _ := strconv.Atoi(part)
		out = append(out, v)
	}
	return out
}

func newer(a, b string) bool {
	x, y := verNum(a), verNum(b)
	for i := 0; i < len(x) || i < len(y); i++ {
		var p, q int
		if i < len(x) {
			p = x[i]
		}
		if i < len(y) {
			q = y[i]
		}
		if p != q {
			return p > q
		}
	}
	return false
}

func fetchRelease(dir string) tea.Cmd {
	return func() tea.Msg {
		local := ""
		if data, err := os.ReadFile(filepath.Join(dir, "Manacode_PlayerRaidsInfo.toc")); err == nil {
			if m := reVersion.FindStringSubmatch(string(data)); m != nil {
				local = m[1]
			}
		}
		req, err := http.NewRequest(http.MethodGet, releaseAPI, nil)
		if err != nil {
			return releaseMsg{local: local}
		}
		req.Header.Set("User-Agent", "Manacode_PlayerRaidsInfo-updater/3.0")
		resp, err := (&http.Client{Timeout: 8 * time.Second}).Do(req)
		if err != nil {
			return releaseMsg{local: local}
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return releaseMsg{local: local}
		}
		var rel struct {
			Tag   string `json:"tag_name"`
			Links struct {
				Self string `json:"self"`
			} `json:"_links"`
		}
		if json.NewDecoder(resp.Body).Decode(&rel) != nil || rel.Tag == "" {
			return releaseMsg{local: local}
		}
		return releaseMsg{tag: rel.Tag, url: rel.Links.Self, local: local, newer: local != "" && newer(rel.Tag, local)}
	}
}

func fetchIndex() tea.Msg {
	body, err := get("index.json")
	if err != nil {
		return indexMsg{err: err}
	}
	var idx index
	if err := json.Unmarshal(body, &idx); err != nil {
		return indexMsg{err: fmt.Errorf("сервер прислал не то: %w", err)}
	}
	if idx.V < 7 || len(idx.Files) == 0 {
		return indexMsg{err: fmt.Errorf("на сервере старый формат выгрузки (v%d)", idx.V)}
	}
	return indexMsg{idx: &idx}
}

func (m *model) buildChoices() {
	m.choices = m.choices[:0]
	for s := m.idx.Season; s >= 0; s-- {
		m.choices = append(m.choices, s)
	}
	m.cursor = 0
	m.sel = map[int]bool{m.idx.Season: true}
	switch {
	case m.fromGame != nil:
		for s := range m.fromGame {
			m.sel[s] = true
		}
	case len(m.cfg.Seasons) > 0:
		for _, s := range m.cfg.Seasons {
			m.sel[s] = true
		}
	case m.cfg.SeasonsFrom != nil:
		for s := m.idx.Season; s >= *m.cfg.SeasonsFrom; s-- {
			m.sel[s] = true
		}
	default:
		for _, s := range m.choices {
			m.sel[s] = true
		}
	}
}

func (m *model) selectedList() []int {
	var out []int
	for _, s := range m.choices {
		if m.sel[s] {
			out = append(out, s)
		}
	}
	return out
}

func (m *model) startDownload() tea.Cmd {
	sel := map[int]bool{}
	for s, on := range m.sel {
		sel[s] = on
	}
	m.cfg.Seasons = m.selectedList()
	m.cfg.SeasonsFrom = nil
	saveConfig(m.dir, m.cfg)
	m.stage = stDownload
	m.started = time.Now()
	var total int64
	for _, f := range m.idx.Files {
		if sel[f.Season] {
			total += f.ZipLen
		}
	}
	m.cnt.got.Store(0)
	m.cnt.total.Store(total)
	m.cnt.file.Store("")
	idx, dir, cnt := *m.idx, m.dir, m.cnt
	return tea.Batch(func() tea.Msg {
		written, err := download(idx, dir, sel, cnt)
		return doneMsg{err: err, written: written}
	}, tick())
}

func tick() tea.Cmd {
	return tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg { return tickMsg(t) })
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyPressMsg:
		k := msg.String()
		if k == "ctrl+c" {
			return m, tea.Quit
		}
		switch m.stage {
		case stChoose:
			switch k {
			case "up", "k", "л":
				if m.cursor > 0 {
					m.cursor--
				}
			case "down", "j", "о":
				if m.cursor < len(m.choices)-1 {
					m.cursor++
				}
			case "space", "x", "ч":
				if s := m.choices[m.cursor]; s != m.idx.Season {
					m.sel[s] = !m.sel[s]
				}
			case "a", "ф":
				all := true
				for _, s := range m.choices {
					all = all && m.sel[s]
				}
				for _, s := range m.choices {
					m.sel[s] = !all || s == m.idx.Season
				}
			case "enter":
				return m, m.startDownload()
			case "esc", "q", "й":
				return m, tea.Quit
			}
		case stDone, stError:
			switch k {
			case "left", "h", "shift+tab":
				if m.btn > 0 {
					m.btn--
				}
			case "right", "l", "tab":
				if m.btn < 2 {
					m.btn++
				}
			case "r", "к":
				m.btn = 0
				return m.press()
			case "s", "ы":
				m.btn = 1
				return m.press()
			case "q", "й", "esc":
				return m, tea.Quit
			case "enter", "space":
				return m.press()
			}
		}
	case indexMsg:
		if msg.err != nil {
			m.stage, m.err = stError, msg.err
			return m, nil
		}
		m.idx = msg.idx
		m.buildChoices()
		m.stage = stChoose
	case releaseMsg:
		rel := msg
		m.release = &rel
	case doneMsg:
		m.took = time.Since(m.started)
		if msg.err != nil {
			m.stage, m.err = stError, msg.err
			return m, nil
		}
		m.written = msg.written
		m.after = readLocal(m.dir)
		m.stage, m.btn = stDone, 2
	case tickMsg:
		if m.stage == stDownload {
			return m, tick()
		}
	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spin, cmd = m.spin.Update(msg)
		return m, cmd
	}
	return m, nil
}

func (m *model) press() (tea.Model, tea.Cmd) {
	switch m.btn {
	case 0:
		m.before = readLocal(m.dir)
		m.err = nil
		if m.idx == nil {
			m.stage = stLoading
			return m, fetchIndex
		}
		m.stage = stLoading
		return m, fetchIndex
	case 1:
		if m.idx == nil {
			return m, nil
		}
		m.buildChoices()
		m.stage = stChoose
		return m, nil
	}
	return m, tea.Quit
}

func mb(n int64) string { return fmt.Sprintf("%.1f МБ", float64(n)/1048576) }

func num(n int) string {
	s := strconv.Itoa(n)
	var b strings.Builder
	for i, r := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			b.WriteRune(' ')
		}
		b.WriteRune(r)
	}
	return b.String()
}

func bakedRU(s string) string {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return s
	}
	return t.In(time.FixedZone("MSK", 3*3600)).Format("02.01 15:04") + " МСК"
}

func (m *model) header() string {
	h := sTitle.Render("Рейды игроков") + sDim.Render("  ·  обновление данных аддона")
	if rel := m.release; rel != nil {
		switch {
		case rel.newer:
			h += "\n" + sPlus.Render("Вышла версия аддона "+rel.tag) + sLabel.Render(" (у вас "+rel.local+"): ") + sVal.Render(rel.url)
		case rel.local != "":
			h += "\n" + sDim.Render("аддон "+rel.local+" — последняя версия")
		}
	}
	return h
}

func (m *model) View() tea.View {
	var lines []string
	lines = append(lines, m.header(), "")
	switch m.stage {
	case stLoading:
		lines = append(lines, m.spin.View()+sLabel.Render(" спрашиваю GitLab, что нового..."))
	case stChoose:
		lines = append(lines, sVal.Render("Какие сезоны хранить?"),
			sLabel.Render("Текущий нужен всегда, прошлые — чтобы смотреть их в окне."), "")
		sizes := map[int]int64{}
		counts := map[int]int{}
		for _, f := range m.idx.Files {
			sizes[f.Season] = f.Bytes
			counts[f.Season] = f.Count
		}
		var total int64
		for i, s := range m.choices {
			box := "[ ]"
			if m.sel[s] {
				box = "[x]"
				total += sizes[s]
			}
			label := fmt.Sprintf("сезон %d", s)
			if s == m.idx.Season {
				box = "[■]"
				label += " — текущий"
			}
			row := fmt.Sprintf("%s %-20s %9s  %s", box, label, mb(sizes[s]), sDim.Render(num(counts[s])+" игроков"))
			switch {
			case i == m.cursor:
				lines = append(lines, sTitle.Render("▸ ")+sVal.Render(row))
			case m.sel[s]:
				lines = append(lines, "  "+lipgloss.NewStyle().Foreground(white).Render(row))
			default:
				lines = append(lines, "  "+sLabel.Render(row))
			}
		}
		lines = append(lines, "", sLabel.Render("Итого на диске: ")+sVal.Render(mb(total))+
			sLabel.Render("   в память при входе: ")+sVal.Render(mb(sizes[m.idx.Season])))
		if m.fromGame != nil {
			lines = append(lines, sDim.Render("Отмечено по настройке в игре (шестерёнка в окне /raids)."))
		}
		lines = append(lines, "", sDim.Render("↑↓ — выбрать   Пробел — отметить   A — все   Enter — скачать   Esc — выйти"))
	case stDownload:
		got, total := m.cnt.got.Load(), m.cnt.total.Load()
		pct := 0.0
		if total > 0 {
			pct = float64(got) / float64(total)
			if pct > 1 {
				pct = 1
			}
		}
		file, _ := m.cnt.file.Load().(string)
		var list []string
		for _, s := range m.selectedList() {
			list = append(list, strconv.Itoa(s))
		}
		lines = append(lines,
			m.spin.View()+sVal.Render(" скачиваю сезоны "+strings.Join(list, ", "))+sLabel.Render("  ·  "+file),
			m.bar.ViewAs(pct)+"  "+sLabel.Render(mb(got)+" из "+mb(total)))
	case stDone:
		lines = append(lines, m.doneView()...)
	case stError:
		lines = append(lines, sErr.Render("Не получилось: ")+sVal.Render(m.err.Error()), "",
			sLabel.Render("Данные не тронуты — в игре останутся прежние."), "")
		lines = append(lines, m.buttons())
	}
	v := tea.NewView(sBox.Render(strings.Join(lines, "\n")) + "\n")
	return v
}

func (m *model) doneView() []string {
	b, a := m.before, m.after
	var out []string
	same := b.Baked != "" && b.Baked == a.Baked
	if same {
		out = append(out, sVal.Render("Новее выгрузки на сервере пока нет — у вас уже эта."))
	} else {
		out = append(out, sPlus.Render("Готово.")+sLabel.Render(fmt.Sprintf(" за %s", m.took.Round(100*time.Millisecond))))
	}
	state := sPlus.Render("полная")
	if !a.Complete {
		state = sErr.Render("неполная")
	}
	out = append(out, "",
		sLabel.Render("выгрузка   ")+sVal.Render(bakedRU(a.Baked))+sLabel.Render("  ·  ")+state,
		sLabel.Render("игроков    ")+sVal.Render(num(a.Count))+m.delta(a.Count-b.Count))
	var seasons []int
	for s := range a.Seasons {
		seasons = append(seasons, s)
	}
	sort.Sort(sort.Reverse(sort.IntSlice(seasons)))
	for _, s := range seasons {
		n := a.Seasons[s]
		row := sLabel.Render(fmt.Sprintf("  сезон %d   ", s))
		if n < 0 {
			row += sDim.Render("не скачан")
		} else {
			row += sVal.Render(num(n)) + sLabel.Render(" игроков") + m.delta(n-b.Seasons[s])
		}
		out = append(out, row)
	}
	out = append(out, "", sLabel.Render("В игре наберите ")+sVal.Render("/reload")+sLabel.Render(" — данные читаются при загрузке."))
	if m.fromGame != nil {
		out = append(out, sDim.Render("Сезоны взяты из настроек в игре."))
	}
	out = append(out, "", m.buttons())
	return out
}

func (m *model) delta(d int) string {
	if d > 0 {
		return "  " + sPlus.Render("+"+num(d))
	}
	if d < 0 {
		return "  " + sErr.Render("-"+num(-d))
	}
	return ""
}

func (m *model) buttons() string {
	names := []string{"Обновить ещё раз  R", "Сезоны  S", "Выход  Q"}
	var parts []string
	for i, n := range names {
		if i == m.btn {
			parts = append(parts, sBtnOn.Render(n))
		} else {
			parts = append(parts, sBtn.Render(n))
		}
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, parts...) + "\n" + sDim.Render("←→ — выбрать   Enter — нажать")
}

func request(name string) (*http.Response, error) {
	req, err := http.NewRequest(http.MethodGet, dataBase+name, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "Manacode_PlayerRaidsInfo-updater/3.0")
	req.Header.Set("Cache-Control", "no-cache")
	resp, err := (&http.Client{Timeout: 10 * time.Minute}).Do(req)
	if err != nil {
		return nil, fmt.Errorf("не удалось соединиться с GitLab")
	}
	switch resp.StatusCode {
	case http.StatusOK:
		return resp, nil
	case http.StatusNotFound:
		resp.Body.Close()
		return nil, fmt.Errorf("на GitLab нет файла %s — выгрузка ещё не опубликована", name)
	default:
		resp.Body.Close()
		return nil, fmt.Errorf("GitLab ответил %s", resp.Status)
	}
}

func get(name string) ([]byte, error) {
	resp, err := request(name)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}

type countingReader struct {
	r   io.Reader
	cnt *counter
}

func (c *countingReader) Read(p []byte) (int, error) {
	n, err := c.r.Read(p)
	c.cnt.got.Add(int64(n))
	return n, err
}

func fetchTo(path string, f fileInfo, cnt *counter) error {
	cnt.file.Store(f.Name)
	resp, err := request(f.Zip)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	zip, err := io.ReadAll(&countingReader{r: resp.Body, cnt: cnt})
	if err != nil {
		return fmt.Errorf("%s: оборвалось скачивание", f.Zip)
	}
	_, data, err := unzipFirstAES(zip, zipPass)
	if err != nil {
		return fmt.Errorf("%s: %w", f.Zip, err)
	}
	s := strings.TrimSpace(string(data))
	if !strings.HasSuffix(s, "}") || !strings.Contains(s, "PlayerRaids") {
		return fmt.Errorf("%s: внутри не тот файл", f.Zip)
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func download(idx index, dir string, sel map[int]bool, cnt *counter) ([]string, error) {
	adir := filepath.Join(filepath.Dir(dir), archiveDir)
	if err := os.MkdirAll(adir, 0o755); err != nil {
		return nil, err
	}
	var written []string
	var archive []fileInfo
	for _, f := range idx.Files {
		if f.Season < idx.Season {
			archive = append(archive, f)
		}
	}
	sort.Slice(archive, func(i, j int) bool { return archive[i].Season > archive[j].Season })
	for _, f := range archive {
		path := filepath.Join(adir, f.Name)
		if sel[f.Season] {
			if err := fetchTo(path, f, cnt); err != nil {
				return written, err
			}
			written = append(written, archiveDir+"/"+f.Name)
			continue
		}
		stub := fmt.Sprintf("PlayerRaidsArchive = PlayerRaidsArchive or {}\nPlayerRaidsArchive[%d] = false\n", f.Season)
		if err := os.WriteFile(path, []byte(stub), 0o644); err != nil {
			return written, err
		}
	}
	var toc strings.Builder
	toc.WriteString("## Interface: 30300\n## Title: Manacode_PlayerRaidsInfo Archive\n## Notes: Прошлые сезоны, грузится по требованию\n## LoadOnDemand: 1\n## Dependencies: Manacode_PlayerRaidsInfo\n")
	for _, f := range archive {
		toc.WriteString(f.Name + "\n")
	}
	if err := os.WriteFile(filepath.Join(adir, archiveToc), []byte(toc.String()), 0o644); err != nil {
		return written, err
	}
	for _, f := range idx.Files {
		if f.Season == idx.Season {
			if err := fetchTo(filepath.Join(dir, mainFile), f, cnt); err != nil {
				return written, err
			}
			written = append(written, mainFile)
		}
	}
	return written, nil
}

var (
	reBaked    = regexp.MustCompile(`baked\s*=\s*"([^"]*)"`)
	reComplete = regexp.MustCompile(`complete\s*=\s*(\w+)`)
	reCount    = regexp.MustCompile(`count\s*=\s*(\d+)`)
	reSVFrom   = regexp.MustCompile(`\["seasonsFrom"\]\s*=\s*(\d+)`)
	reSVSet    = regexp.MustCompile(`(?s)\["seasons"\]\s*=\s*\{(.*?)\}`)
	reSVItem   = regexp.MustCompile(`\[(\d+)\]\s*=\s*true`)
	reArchIdx  = regexp.MustCompile(`PlayerRaidsArchive\[(\d+)\]\s*=\s*(false|\{)`)
)

func tail(path string, n int64) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	fi, err := f.Stat()
	if err != nil {
		return ""
	}
	off := fi.Size() - n
	if off < 0 {
		off = 0
	}
	buf := make([]byte, fi.Size()-off)
	_, _ = f.ReadAt(buf, off)
	return string(buf)
}

func countLines(path string) int {
	data, err := os.ReadFile(path)
	if err != nil {
		return -1
	}
	return strings.Count(string(data), "\n[")
}

func readLocal(dir string) localMeta {
	lm := localMeta{Seasons: map[int]int{}}
	t := tail(filepath.Join(dir, mainFile), 4096)
	if m := reBaked.FindStringSubmatch(t); m != nil {
		lm.Baked = m[1]
	}
	if m := reComplete.FindStringSubmatch(t); m != nil {
		lm.Complete = m[1] == "true"
	}
	if m := reCount.FindStringSubmatch(t); m != nil {
		lm.Count, _ = strconv.Atoi(m[1])
	}
	adir := filepath.Join(filepath.Dir(dir), archiveDir)
	entries, _ := os.ReadDir(adir)
	for _, e := range entries {
		name := e.Name()
		if !strings.HasPrefix(name, "Data_s") || !strings.HasSuffix(name, ".lua") {
			continue
		}
		s, err := strconv.Atoi(strings.TrimSuffix(strings.TrimPrefix(name, "Data_s"), ".lua"))
		if err != nil {
			continue
		}
		head := tail(filepath.Join(adir, name), 1<<30)
		if m := reArchIdx.FindStringSubmatch(head); m != nil && m[2] == "false" {
			lm.Seasons[s] = -1
			continue
		}
		lm.Seasons[s] = countLines(filepath.Join(adir, name))
	}
	return lm
}

func seasonsFromGame(dir string) map[int]bool {
	wtf := filepath.Join(dir, "..", "..", "..", "WTF", "Account")
	files, _ := filepath.Glob(filepath.Join(wtf, "*", "SavedVariables", addonSVName))
	var best map[int]bool
	var bestTime time.Time
	for _, f := range files {
		fi, err := os.Stat(f)
		if err != nil {
			continue
		}
		data, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		set := map[int]bool{}
		if m := reSVSet.FindStringSubmatch(string(data)); m != nil {
			for _, it := range reSVItem.FindAllStringSubmatch(m[1], -1) {
				if v, err := strconv.Atoi(it[1]); err == nil {
					set[v] = true
				}
			}
		} else if m := reSVFrom.FindStringSubmatch(string(data)); m != nil {
			if v, err := strconv.Atoi(m[1]); err == nil {
				for x := v; x <= 20; x++ {
					set[x] = true
				}
			}
		}
		if len(set) == 0 {
			continue
		}
		if best == nil || fi.ModTime().After(bestTime) {
			best, bestTime = set, fi.ModTime()
		}
	}
	return best
}

func loadConfig(dir string) config {
	var c config
	data, err := os.ReadFile(filepath.Join(dir, configFile))
	if err == nil {
		_ = json.Unmarshal(data, &c)
	}
	return c
}

func saveConfig(dir string, c config) {
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return
	}
	_ = os.WriteFile(filepath.Join(dir, configFile), data, 0o644)
}

func exeDir() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", err
	}
	return filepath.Dir(exe), nil
}
