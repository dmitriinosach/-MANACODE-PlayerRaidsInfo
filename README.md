# Manacode_PlayerRaidsInfo

Аддон для WoW 3.3.5 (WoW Circle): статистика рейдов игроков прямо в игре — ЦЛК 25 гер, анбаф и об, РС 25. Окно `/raids` ищет по нику, в том числе по старым, и показывает рейды игрока по сезонам: урон, хил, танк, парсы, вайпы. Если зажать Alt и навести на ник в чате или на игрока, появится короткая карточка.

Скачать аддон — [релизы на GitHub](https://github.com/dmitriinosach/-MANACODE-PlayerRaidsInfo/releases/latest): распакуйте архив в `Interface\AddOns`.

Аддон сам не ходит в интернет — данные лежат файлами в его папке `data`. Чтобы их обновить, запустите `ОбновитьДанные.exe` в папке аддона, выберите сезоны и наберите в игре `/reload`. Когда выходит новая версия аддона, та же программа ставит её клавишей `U`.

Без exe: на [странице данных](https://github.com/dmitriinosach/-MANACODE-PlayerRaidsInfo/tree/data) скачайте `season_all.zip` — все сезоны сразу — или `seasonN.zip` по одному, откройте в 7-Zip или WinRAR паролем `raids-circle` и положите файлы `Data.lua` и `Data_sN.lua` в `Interface\AddOns\Manacode_PlayerRaidsInfo\data`.

Вопросы — в [Discord](https://discord.gg/hpTkJCJbwn).
