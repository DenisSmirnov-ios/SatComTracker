# Changelog

## Рефакторинг и оптимизация (структура проекта и логика)

### Разделение кода по файлам

Раньше весь код приложения находился в одном файле `ContentView.swift` (~3200 строк). Код разнесён по отдельным модулям:

| Файл | Содержимое |
|------|------------|
| **Models.swift** | Модели данных: `APIConfig`, `Satellite`, `CachedData`, `SatellitePositionsResponse`, `SatelliteFrequencyData`, `SatcomReference`, `SatcomSatellite`, `LocationSearchResult`, `MapLocation` |
| **FrequencyStore.swift** | Класс `FrequencyStore` (синглтон), вложенные типы `CommunicationChannel`, `SatelliteFrequencies`, предустановленные частоты спутников |
| **AppSettings.swift** | Класс `AppSettings`, enum `LocationSource` (GPS / ручной ввод / карта) |
| **SatelliteAPI.swift** | Класс `SatelliteAPI` — запросы к N2YO API, кеширование, повторные попытки |
| **LocationManager.swift** | Класс `LocationManager` — работа с GPS (CLLocationManager) |
| **CompassManager.swift** | Класс `CompassManager` — магнитный компас |
| **GeocoderManager.swift** | Класс `GeocoderManager` — поиск адресов и обратное геокодирование |
| **ContentView.swift** | Только UI: экраны, списки, карта, настройки, превью (~1935 строк) |
| **SatComTrackerApp.swift** | Точка входа приложения (без изменений) |

Итог: один большой файл заменён на 9 целевых файлов, упрощена навигация и поддержка кода.

---

### Оптимизации и исправления

#### 1. Безопасная работа с жестом в MapView
- **Было:** `gesture.view as! MKMapView` — при неожиданном типе возможен крэш.
- **Стало:** `guard let mapView = gesture.view as? MKMapView else { return }` — безопасное приведение типа.

#### 2. Отвязка SatelliteAPI от AppSettings
- **Было:** Метод `fetchSatellites(..., settings: AppSettings)` вызывал внутри `settings.updateCacheTime()`, сервис зависел от типа настроек.
- **Стало:** Сигнатура `fetchSatellites(..., onCacheUpdated: (() -> Void)? = nil)`. При успешном обновлении данных вызывается переданный замыкание; вызывающий код (например, `ContentView`) при необходимости вызывает `settings.updateCacheTime()`.

#### 3. Ограничение параллельных запросов к API (батчинг)
- **Было:** Все запросы к N2YO добавлялись в одну `TaskGroup`, ограничение по количеству одновременных запросов по сути не работало.
- **Стало:** Запросы выполняются батчами по `APIConfig.maxConcurrentRequests` (5). Одновременно к API уходит не более 5 запросов, лимиты N2YO соблюдаются.

#### 4. Время последнего обновления из кеша
- **Было:** `getValidCache` возвращал только `[Satellite]?`, при загрузке из кеша время бралось из настроек.
- **Стало:** `getValidCache` возвращает `(satellites: [Satellite], timestamp: Date)?`. При показе данных из кеша отображается реальное время кеша (`lastUpdateTime = cached.timestamp`).

#### 5. Соответствие AppSettings протоколу ObservableObject
- В `AppSettings.swift` добавлен `import Combine`, чтобы протокол `ObservableObject` был однозначно виден при использовании типа в других файлах (например, `@ObservedObject var settings: AppSettings`).

---

### Зависимости между модулями

- **Models** — не зависит от других модулей приложения.
- **FrequencyStore** — использует `SatelliteFrequencyData` из Models.
- **AppSettings** — использует `SatcomReference` из Models.
- **SatelliteAPI** — использует `APIConfig`, `Satellite`, `CachedData`, `SatellitePositionsResponse` из Models.
- **GeocoderManager** — использует `LocationSearchResult` из Models.
- **ContentView** — использует все перечисленные типы и сервисы.

---

### Что не менялось

- Поведение приложения для пользователя (экранный поток, настройки, список спутников, карта, частоты).
- Формат кеша и хранение в UserDefaults.
- Набор предустановленных частот и справочник спутников.
- Минимальная версия iOS и настройки проекта.

---

*Дата рефакторинга: 03.2026*
