//
//  ViewController.swift
//  farmSquare
//
//  Created by Черных Елена on 29.05.2019.
//  Copyright © 2019 Alphacentaura. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import AVFoundation

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var startStopButton: UIBarButtonItem!
    
    
    var precision: Double = 0.00001
    var locationManager = CLLocationManager()
    var pointsArray = [CLLocationCoordinate2D]()
    var locationsArray = [CLLocation]()
    
    @IBOutlet weak var textOut: PaddingLabel!
    weak var timer: Timer?
    var timerDispatchSourceTimer : DispatchSourceTimer?
    
    var startTracking = false
    let kEarthRadius = 6378137.0
    // CLLocationCoordinate2D uses degrees but we need radians
    func radians(degrees: Double) -> Double {
        return degrees * Double.pi / 180
    }
    
    func regionArea(locations: [CLLocationCoordinate2D]) -> Double {
        
        guard locations.count > 2 else { return 0 }
        var area = 0.0
        
        for i in 0..<locations.count {
            let p1 = locations[i > 0 ? i - 1 : locations.count - 1]
            let p2 = locations[i]
            
            area += radians(degrees: p2.longitude - p1.longitude) * (2 + sin(radians(degrees: p1.latitude)) + sin(radians(degrees: p2.latitude)) )
        }
        
        area = -(area * kEarthRadius * kEarthRadius / 2)
        
        return max(area, -area) // In order not to worry about is polygon clockwise or counterclockwise defined.
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.borderColor = UIColor.red.cgColor
        
        self.mapView.delegate = self
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = 10
            // Ask for Authorisation from the User.
            self.locationManager.requestAlwaysAuthorization()
            // For use in foreground
            locationManager.requestWhenInUseAuthorization()
            //locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            
            locateMe()
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let lineView = MKPolylineRenderer(overlay: overlay)
            lineView.strokeColor = UIColor.red
            
            return lineView
        }
        
        return MKOverlayRenderer()
    }

    
    func addPolyLineToMap(locations: [CLLocation?]) {
        var coordinates = locations.map({ (location: CLLocation!) -> CLLocationCoordinate2D in return location.coordinate });
        let polyline = MKPolyline(coordinates: &coordinates, count: locations.count);
        self.mapView.addOverlay(polyline)
    }
    
    func locateMe() {
        locationManager.startUpdatingLocation()
        mapView.showsUserLocation = true
    }
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if let location = locations.first {
            let span = MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            let region = MKCoordinateRegion(center: location.coordinate, span: span)
            mapView.setRegion(region, animated: true)
        }
        
        let userLocation: CLLocation = locations.last!
        //let latitude = userLocation.coordinate.latitude
        //let longitude = userLocation.coordinate.longitude
        
        self.mapView.showsUserLocation = true
        
        if self.startTracking {
            //self.textOut.text = self.textOut.text! + " lat = \(latitude) long = \(longitude)"
            self.locationsArray.append(userLocation)
            self.pointsArray.append(userLocation.coordinate)
            
            // draw our route
            self.mapView.removeOverlays(self.mapView.overlays)
            self.addPolyLineToMap(locations: self.locationsArray)
        } else {
            //self.textOut.text = " lat = \(latitude) long = \(longitude)"
        }
    }

    @IBAction func startAction(_ sender: Any) {
        if(self.startTracking) {
            
            self.startStopButton.title = "Начать замер"
            self.view.layer.borderWidth = 0.0;
            
            self.startTracking = false
            locationManager.stopUpdatingLocation();
            if self.pointsArray.count > 0 {
                self.pointsArray.append(self.pointsArray.first!)
            }
            var area = self.regionArea(locations: self.pointsArray)
            
            if self.locationsArray.count > 0 {
                self.locationsArray.append(self.locationsArray.first!)
            }
            self.mapView.removeOverlays(self.mapView.overlays)
            self.addPolyLineToMap(locations: self.locationsArray)
            
            if area > 0 {
                area = Double(area).rounded(toPlaces: 4)
            }
            self.textOut.isHidden = false
            self.textOut.text = "Площадь участка: \(area) кв.м."
        } else {
            self.textOut.isHidden = true
            self.view.layer.borderWidth = 3.0;
            self.startStopButton.title = "Закончить"
            self.startTracking = true
            self.mapView.removeOverlays(self.mapView.overlays)
            self.pointsArray = [CLLocationCoordinate2D]()
            self.locationsArray = [CLLocation]()
            self.locateMe()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if(status == CLAuthorizationStatus.denied) {
            showLocationDisabledPopUp()
        }
    }
    
    func showLocationDisabledPopUp() {
        let alertController = UIAlertController(title: "Не дано разрешение на получение координат", message: "Для нормальной работы приложения необходимо предоставить доступ к текущему местоположению!", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        let openAction = UIAlertAction(title: "Открыть Настройки", style: .default) { (action) in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        alertController.addAction(openAction)
        self.present(alertController, animated: true, completion:nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Unable to access your current location!")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
@IBDesignable class PaddingLabel: UILabel {
    
    @IBInspectable var topInset: CGFloat = 5.0
    @IBInspectable var bottomInset: CGFloat = 5.0
    @IBInspectable var leftInset: CGFloat = 7.0
    @IBInspectable var rightInset: CGFloat = 7.0
    
    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        super.drawText(in: rect.inset(by: insets))
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + leftInset + rightInset,
                      height: size.height + topInset + bottomInset)
    }
}
