import Foundation
import CoreLocation

final class WeatherManager: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var locationCompletion: ((Result<(Double, Double), Error>) -> Void)?
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation(completion: @escaping (Result<(Double, Double), Error>) -> Void) {
        locationCompletion = completion
        let status = CLLocationManager.authorizationStatus()
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else {
            locationCompletion?(.failure(NSError(domain: "WeatherManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No location"])))
            locationCompletion = nil
            return
        }
        locationCompletion?(.success((loc.coordinate.latitude, loc.coordinate.longitude)))
        locationCompletion = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationCompletion?(.failure(error))
        locationCompletion = nil
    }

    // Fetch current temperature using Open-Meteo (no API key required)
    func fetchTemperature(lat: Double, lon: Double, completion: @escaping (Result<Double, Error>) -> Void) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true&temperature_unit=celsius"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "WeatherManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, resp, err in
            if let err = err {
                completion(.failure(err))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "WeatherManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let current = json["current_weather"] as? [String: Any],
                   let temp = current["temperature"] as? Double {
                    completion(.success(temp))
                } else {
                    completion(.failure(NSError(domain: "WeatherManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "Malformed response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }

    func reverseGeocode(lat: Double, lon: Double, completion: @escaping (Result<String, Error>) -> Void) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: lat, longitude: lon)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let err = error {
                completion(.failure(err))
                return
            }
            if let placemark = placemarks?.first {
                if let locality = placemark.locality {
                    completion(.success(locality))
                    return
                } else if let admin = placemark.administrativeArea {
                    completion(.success(admin))
                    return
                } else if let country = placemark.country {
                    completion(.success(country))
                    return
                }
            }
            completion(.failure(NSError(domain: "WeatherManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "Could not determine locality"])))
        }
    }

    struct Forecast {
        let max: Double
        let min: Double
        let condition: String
    }

    func fetchForecast(lat: Double, lon: Double, forDate date: Date, completion: @escaping (Result<Forecast, Error>) -> Void) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: date)
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=temperature_2m_max,temperature_2m_min,weathercode&timezone=auto&start_date=\(dateStr)&end_date=\(dateStr)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "WeatherManager", code: -6, userInfo: [NSLocalizedDescriptionKey: "Invalid forecast URL"])))
            return
        }

        URLSession.shared.dataTask(with: url) { data, resp, err in
            if let err = err {
                completion(.failure(err)); return
            }
            guard let data = data else { completion(.failure(NSError(domain: "WeatherManager", code: -7, userInfo: [NSLocalizedDescriptionKey: "No data"]))); return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let daily = json["daily"] as? [String: Any],
                   let maxArr = daily["temperature_2m_max"] as? [Double],
                   let minArr = daily["temperature_2m_min"] as? [Double],
                   let codes = daily["weathercode"] as? [Int],
                   let max = maxArr.first, let min = minArr.first, let code = codes.first {
                    let condition = Self.conditionDescription(for: code)
                    completion(.success(Forecast(max: max, min: min, condition: condition)))
                } else {
                    completion(.failure(NSError(domain: "WeatherManager", code: -8, userInfo: [NSLocalizedDescriptionKey: "Malformed forecast"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private static func conditionDescription(for code: Int) -> String {
        switch code {
        case 0: return "clear skies"
        case 1,2,3: return "partly cloudy"
        case 45,48: return "fog"
        case 51,53,55: return "drizzle"
        case 61,63,65: return "rain"
        case 71,73,75: return "snow"
        case 80,81,82: return "showers"
        default: return "mixed conditions"
        }
    }
}
