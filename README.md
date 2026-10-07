# Manacode_PlayerRaidsInfo

Аддон для WoW 3.3.5 (WoW Circle): статистика рейдов игроков прямо в игре — ЦЛК, РС и ИВК, 25 и 10, гер и об, все боссы, килы в анбафе. Окно `/raids` ищет по нику, в том числе по старым, и показывает рейды игрока по сезонам: урон, хил, танк, парсы, вайпы. Если зажать Alt и навести на ник в чате или на игрока, появится короткая карточка.

Откуда данные: рейды, парсы и рейтинг спека — из логов WoW Circle. То же написано в окне `/raids`, кнопка «Откуда данные» внизу.

Скачать аддон — [релизы на GitHub](https://github.com/dmitriinosach/-MANACODE-PlayerRaidsInfo/releases/latest): распакуйте архив в `Interface\AddOns`.

Аддон сам не ходит в интернет — данные лежат файлами в его папке `data`. Их и сами аддоны обновляет программа [ManacodeUpdate](https://github.com/dmitriinosach/-MANACODE-Update/releases/latest): выберите PlayerRaidsInfo, отметьте сезоны и рейды и нажмите «Скачать выбранное», потом наберите в игре `/reload`. Там же — новая версия аддона и автообновление в фоне.

Без программы: в папке [`v13` ветки `data`](https://github.com/dmitriinosach/-MANACODE-PlayerRaidsInfo/tree/data/v13) скачайте `all.zip` — всё сразу — или архивы по одному: `players.zip` нужен всегда, `s7.zip` — сезон 7, `s7_icc25h.zip` — его ЦЛК 25 гер и так далее. Распакуйте их в 7-Zip или WinRAR паролем `raids-circle` в `Interface\AddOns` с заменой файлов.

Вопросы — в [Discord](https://discord.gg/hpTkJCJbwn).
