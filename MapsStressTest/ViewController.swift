//
//  ViewController.swift
//  MapsStressTest
//
//  Created by Frederik Hansen on 15/08/2022.
//

import UIKit
import GoogleMaps
import FPSCounter

extension UIColor {
    static var random: UIColor {
        return .init(hue: .random(in: 0...1), saturation: 1, brightness: 1, alpha: 1)
    }
}

class ViewController: UIViewController, GMSMapViewDelegate, FPSCounterDelegate {

    private var markers = [GMSMarker]()
    private var box : GMSPolyline?
    
    // array of lat/lngs
    private var markerPositions = [CLLocationCoordinate2D]()

    // dict to keep track of whether a given marker position is rendered with a marker, or not
    private var isRendered = [String : Bool]()
    
    // frame rate counter
    private var fpsCounter = FPSCounter()
    
    // 0 = "add/remove markers"-rendering approach
    // 1 = "toggle visibility"-rendering approach
    let RENDER_MODE = 1
    
    let NUMBER_OF_MARKERS = 500
    
    private var lastRender = NSDate().timeIntervalSince1970
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fpsCounter.delegate = self
        fpsCounter.startTracking(inRunLoop: RunLoop.main, mode: RunLoop.Mode.default)
                
        // Bounds of Aalborg arae
        let northEastLat = 57.07330227940989
        let northEastLng = 9.979964838523783
        let southWestLat = 57.019143450790736
        let southWestLng = 9.870788205125782
        
        let camera = GMSCameraPosition.camera(withLatitude: 57.03764103248377, longitude: 9.93104134722095, zoom: 15.0)
        let mapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
        self.view.addSubview(mapView)
        
        mapView.preferredFrameRate = GMSFrameRate.maximum
        
        for _ in 0...NUMBER_OF_MARKERS {
            let randomLat = Double.random(in: southWestLat...northEastLat)
            let randomLng = Double.random(in: southWestLng...northEastLng)
            let pos = CLLocationCoordinate2D(latitude: randomLat, longitude: randomLng)
            markerPositions.append(pos)
            isRendered["\(pos)"] = false
            
            if(RENDER_MODE == 1){
                let marker = GMSMarker()
                marker.position = CLLocationCoordinate2D(latitude: randomLat, longitude: randomLng)
                marker.icon = GMSMarker.markerImage(with: .random)
                marker.map = mapView
                markers.append(marker)
            }
        }
        
        mapView.delegate = self
    }
    
    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
      print("You tapped at \(coordinate.latitude), \(coordinate.longitude)")
    }
    
    func interpolate(a: Double, b: Double) -> Double {
        return (a+b)/2
    }
    
    func drawBox(mapView: GMSMapView, nearLeft: CLLocationCoordinate2D,
                 farLeft: CLLocationCoordinate2D, farRight: CLLocationCoordinate2D,
                 nearRight: CLLocationCoordinate2D) -> GMSCoordinateBounds {
        box?.map = nil
        let path = GMSMutablePath()
        path.add(nearLeft)
        path.add(farLeft)
        path.add(farRight)
        path.add(nearRight)
        path.add(nearLeft)
        
        box = GMSPolyline(path: path)
        box!.strokeColor = .blue
        box!.strokeWidth = 5.0
        box!.map = mapView
        
        return GMSCoordinateBounds.init(path: path)
    }
    
    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
        
        // Compute view box geometry
        let visibleRegion = mapView.projection.visibleRegion()
        let center = position.target
        let nearLeftPoint = CLLocationCoordinate2D(latitude: interpolate(a: visibleRegion.nearLeft.latitude, b: center.latitude)
                                                  ,longitude: interpolate(a: visibleRegion.nearLeft.longitude, b: center.longitude))
        let farLeftPoint = CLLocationCoordinate2D(latitude: interpolate(a: visibleRegion.farLeft.latitude, b: center.latitude)
                                                 ,longitude: interpolate(a: visibleRegion.farLeft.longitude, b: center.longitude))
        let farRightPoint = CLLocationCoordinate2D(latitude: interpolate(a: visibleRegion.farRight.latitude, b: center.latitude)
                                                  ,longitude: interpolate(a: visibleRegion.farRight.longitude, b: center.longitude))
        let nearRightPoint = CLLocationCoordinate2D(latitude: interpolate(a: visibleRegion.nearRight.latitude, b: center.latitude)
                                                    ,longitude: interpolate(a: visibleRegion.nearRight.longitude, b: center.longitude))
        // draw the view box, and get its bounds
        let boxBounds = drawBox(mapView: mapView, nearLeft: nearLeftPoint, farLeft: farLeftPoint, farRight: farRightPoint, nearRight: nearRightPoint)
        
        
        // If we have rendered in the past 100 ms, then dont render
        if(self.lastRender + 0.1 > NSDate().timeIntervalSince1970){
            return
        }
        
        DispatchQueue.global().async {
                DispatchQueue.main.async(execute: {
                    // Render behavior for "add/remove markers"-rendering approach
                    if(self.RENDER_MODE == 0){
                        // Remove markers
                        for marker in self.markers {
                            if(!boxBounds.contains(marker.position)){
                                marker.map = nil
                                self.isRendered["\(marker.position)"] = false
                                let index = self.markers.firstIndex(of: marker)
                                self.markers.remove(at: index!)
                            }
                        }
                        
                        // Add markers, if inside box and isn't already rendered
                        for pos in self.markerPositions {
                            let isRendered = self.isRendered["\(pos)"]
                            if(isRendered != nil && !(isRendered!) && boxBounds.contains(pos) ){
                                let marker = GMSMarker()
                                marker.position = pos
                                marker.icon = GMSMarker.markerImage(with: .random)
                                marker.map = mapView
                                self.markers.append(marker)
                                self.isRendered["\(pos)"] = true
                            }
                        }
                    }
                    
                    // Render behavior for "toggle visibility"-rendering approach
                    if(self.RENDER_MODE == 1){
                        for marker in self.markers {
                            if(boxBounds.contains(marker.position)){
                                marker.opacity = 1
                            } else {
                                marker.opacity = 0
                            }
                        }
                    }
                    
                    self.lastRender = NSDate().timeIntervalSince1970
                    
                })
            }
    }
    
    func fpsCounter(_ counter: FPSCounter, didUpdateFramesPerSecond fps: Int) {
        print("FPS: " + String(fps))
    }


}

