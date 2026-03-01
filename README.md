# SATCOM Трекер

<p align="center">
  <strong>iOS-приложение для отслеживания спутников военной и коммерческой спутниковой связи (SATCOM)</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2015.6+-blue" alt="iOS 15.6+">
  <img src="https://img.shields.io/badge/Swift-5.0-orange" alt="Swift 5">
  <img src="https://img.shields.io/badge/SwiftUI-✓-green" alt="SwiftUI">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="License MIT">
</p>

---

## Описание

**SATCOM Трекер** — приложение для наблюдения за положением спутников SATCOM в реальном времени. Показывает азимут и угол места (элевацию), список предустановленных частот по спутникам (UFO, Skynet, SICRAL, INTELSAT и др.), компас для наведения антенны и карту для выбора точки наблюдения.

Данные о положении спутников получаются через [N2YO API](https://www.n2yo.com/api/). Для работы нужен бесплатный API-ключ (регистрация на сайте N2YO).

---

## Возможности

- **Позиции спутников** — азимут, элевация, расстояние, время обновления
- **Список спутников** — выбор из справочника (UFO 10/11, Skynet, SICRAL, INTELSAT 22 и др.)
- **Частоты** — предустановленные каналы по спутникам, возможность добавлять и редактировать каналы
- **Компас** — направление на спутник с учётом магнитного склонения
- **Источники местоположения** — GPS, ручной ввод координат, выбор точки на карте
- **Кеширование** — сохранение данных с настраиваемым интервалом обновления (5 мин — 4 ч)
- **Интерфейс на русском языке**

---

## Требования

- iOS 15.6 или новее
- Xcode 15+ (для сборки)
- API-ключ [N2YO](https://www.n2yo.com/api/)

---

## Установка и сборка

1. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/DenisSmirnov-ios/SatComTracker.git
   cd SatComTracker
   ```

2. Откройте проект в Xcode:
   ```bash
   open SatComTracker.xcodeproj
   ```

3. Выберите целевое устройство или симулятор и нажмите **Run** (⌘R).

4. При первом запуске откройте **Настройки** (иконка шестерёнки), введите API-ключ N2YO и при необходимости выберите спутники и источник местоположения.

---

## Структура проекта

```
SatComTracker/
├── SatComTracker/
│   ├── SatComTrackerApp.swift    # Точка входа
│   ├── ContentView.swift         # Основной UI (списки, экраны, карта, настройки)
│   ├── Models.swift              # Модели данных (Satellite, CachedData, SatcomReference и др.)
│   ├── AppSettings.swift         # Настройки приложения (API, координаты, интервал)
│   ├── SatelliteAPI.swift        # Запросы к N2YO API, кеш, батчинг
│   ├── FrequencyStore.swift      # Хранилище частот и предустановленные каналы
│   ├── LocationManager.swift    # GPS / CLLocationManager
│   ├── CompassManager.swift      # Магнитный компас
│   ├── GeocoderManager.swift    # Поиск адресов и геокодирование
│   ├── Info.plist
│   └── Assets.xcassets
├── SatComTracker.xcodeproj
├── README.md
├── CHANGELOG.md
├── LICENSE
└── .gitignore
```

---

## API и лимиты

Приложение использует [N2YO REST API](https://www.n2yo.com/api/). Бесплатный ключ имеет ограничения по количеству запросов в день. В настройках можно задать интервал обновления (рекомендуется не чаще 15–30 минут при большом числе спутников). Запросы к API выполняются батчами (не более 5 одновременно), чтобы не превышать лимиты.

---

## Лицензия

Проект распространяется под лицензией [MIT](LICENSE). Использование N2YO API регулируется [условиями N2YO](https://www.n2yo.com/api/).

---

## Changelog

История изменений — в [CHANGELOG.md](CHANGELOG.md).

---

