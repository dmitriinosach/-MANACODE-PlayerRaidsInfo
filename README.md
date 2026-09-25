# Manacode_PlayerRaidsInfo

Аддон для WoW 3.3.5 (WoW Circle): статистика рейдов игроков прямо в игре

Откуда данные: рейды — из логов WoW Circle, рейтинг игроков и парсы — с сайта [Боберлогс](https://boberlogs.top). 

Скачать аддон — [релизы на GitHub](https://github.com/dmitriinosach/-MANACODE-PlayerRaidsInfo/releases/latest): распакуйте архив в `Interface\AddOns`.

Аддон сам не ходит в интернет — данные лежат файлами в его папке `data`. Чтобы их обновить, запустите `ОбновитьДанные.exe` в папке аддона, выберите сезоны и наберите в игре `/reload`. Когда выходит новая версия аддона, та же программа ставит её клавишей `U`.

Без exe: на [странице данных](https://github.com/dmitriinosach/-MANACODE-PlayerRaidsInfo/tree/data) скачайте `season_all.zip` — все сезоны сразу — или `seasonN.zip` по одному, откройте в 7-Zip или WinRAR паролем `raids-circle` и положите файлы `Data.lua` и `Data_sN.lua` в `Interface\AddOns\Manacode_PlayerRaidsInfo\data`.

Вопросы — в [Discord](https://discord.gg/hpTkJCJbwn).
