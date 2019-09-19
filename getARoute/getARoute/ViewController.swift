import UIKit
import GoogleMaps
import GooglePlaces
import Alamofire
import SwiftyJSON

enum Route {
    case startPoint
    case destinationPoint
}

class MapViewController: UIViewController {
    
    @IBOutlet weak var mapView: GMSMapView!
    
    @IBOutlet weak var startPoint: UITextField!
    @IBOutlet weak var destinationPoint: UITextField!
   
    @IBOutlet weak var startGeolocation: UIButton!
    @IBOutlet weak var destinationGeolocation: UIButton!
    
     @IBOutlet weak var searchButton: UIButton!
    
    var currentField = Route.startPoint
    
    private let locationManager = CLLocationManager()
    var myLocation :CLLocationCoordinate2D?
    
    var markerStart = GMSMarker()
    var markerDestination = GMSMarker()
    
    var startName = String()
    var destinationName = String()
    
    var startCoordinates = String()
    var destinationCoordinates = String()
    
    var polyline = GMSPolyline.init()
    
    
    override func viewDidLoad() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        startPoint.placeholder = "Start point"
        destinationPoint.placeholder = "Destination"
        searchButton.layer.cornerRadius = 5
    }
    
    @IBAction func chooseStartPoint(_ sender: UITextField) {
        currentField = .startPoint
        startPoint.resignFirstResponder()
        let acController = GMSAutocompleteViewController()
        acController.delegate = self
        present(acController, animated: true, completion: nil)
    }
    
    @IBAction func chooseDestinationPoint(_ sender: UITextField) {
        currentField = .destinationPoint
        destinationPoint.resignFirstResponder()
        let acController = GMSAutocompleteViewController()
        acController.delegate = self
        present(acController, animated: true, completion: nil)
    }
    
    @IBAction func styleMap(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            mapView.mapType = .normal
        case 1:
            mapView.mapType = .satellite
        case 2:
            mapView.mapType = .hybrid
        default:
            mapView.mapType = .normal
        }
    }
    
    @IBAction func startFromCurrentLocation(_ sender: UIButton) {
        markerStart.map = nil
        markerStart = GMSMarker(position: myLocation!)
        markerStart.map = mapView
        startPoint.text = "current location"
        startCoordinates = "\(myLocation!.latitude),\(myLocation!.longitude)"
        self.polyline.map = nil
    }
    
    @IBAction func destinationIsCurrentLocation(_ sender: UIButton) {
        markerDestination.map = nil
        markerDestination = GMSMarker(position: myLocation!)
        markerDestination.map = mapView
        destinationPoint.text = "current location"
        destinationCoordinates = "\(myLocation!.latitude),\(myLocation!.longitude)"
        self.polyline.map = nil
    }

    @IBAction func searchRoute(_ sender: UIButton) {
        let url = "https://maps.googleapis.com/maps/api/directions/json?origin=\(startCoordinates)&destination=\(destinationCoordinates)&mode=driving&key=AIzaSyB3B5xrNumL1JeZ3_xu-Kz2b4Oe9eKCTPE"
        
        zoomRoute()
        self.polyline.map = nil
        Alamofire.request(url).responseJSON { response in
            do {
                let json = try JSON(data: response.data!)
                let status = json["status"]
                if (status == "ZERO_RESULTS") {
                    self.routeError()
                }
                else {
                    let routes = json["routes"].arrayValue
                    for route in routes
                    {
                        let routeOverviewPolyline = route["overview_polyline"].dictionary
                        let points = routeOverviewPolyline?["points"]?.stringValue
                        let path = GMSPath.init(fromEncodedPath: points!)
                        self.polyline = GMSPolyline.init(path: path)
                        self.polyline.strokeColor = UIColor.blue
                        self.polyline.strokeWidth = 3
                        self.polyline.map = self.mapView
                    }
                }
            }
            catch  {
                print("Error")
            }
        }
    }
    
    func zoomRoute() {
        var bounds = GMSCoordinateBounds()
        bounds = bounds.includingCoordinate(self.markerStart.position)
        bounds = bounds.includingCoordinate(self.markerDestination.position)
        
        let update = GMSCameraUpdate.fit(bounds, withPadding: 100)
        self.mapView.animate(with: update)
    }
    
    func routeError() {
        let alert = UIAlertController(title: "Error", message: "Such route not found", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alert, animated: true)
    }
}


extension MapViewController: GMSAutocompleteViewControllerDelegate {
    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        let position = CLLocationCoordinate2D(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        
        self.polyline.map = nil
        if (currentField == .startPoint) {
            markerStart.map = nil
            markerStart = GMSMarker(position: position)
            markerStart.map = mapView
            startPoint.text = place.name
            
            startCoordinates = "\(place.coordinate.latitude),\(place.coordinate.longitude)"
            
            dismiss(animated: true, completion: nil)
        }
        else if (currentField == .destinationPoint) {
            markerDestination.map = nil
            markerDestination = GMSMarker(position: position)
            markerDestination.map = mapView
            destinationPoint.text = place.name
            
            destinationCoordinates = "\(place.coordinate.latitude),\(place.coordinate.longitude)"

            dismiss(animated: true, completion: nil)
        }
        mapView.camera = GMSCameraPosition(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude, zoom: 15)
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        print("Error: ", error.localizedDescription)
    }
    
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        dismiss(animated: true, completion: nil)
    }
}

extension MapViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard status == .authorizedWhenInUse else {
            return
        }
        locationManager.startUpdatingLocation()
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            return
        }
        myLocation = location.coordinate
        mapView.camera = GMSCameraPosition(target: location.coordinate, zoom: 15, bearing: 0, viewingAngle: 0)
        locationManager.stopUpdatingLocation()
    }
}
