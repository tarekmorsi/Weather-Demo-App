//
//  ViewController.swift
//  WeatherDemoApp
//
//  Created by Tarek Morsi on 6/9/19.
//  Copyright © 2019 Tarek Morsi. All rights reserved.
//

import UIKit
import MapKit
import JKBottomSearchView
import Firebase
import EFCountingLabel


class LandingVC: UIViewController  {
    
    //Firebase
    var ref: DatabaseReference!

    //Location Manager & Map View
    let locationManager = CLLocationManager()
    let annotation = MKPointAnnotation()
    var matchingItems:[MKMapItem] = []
    var previewItems:[MKMapItem] = []
    @IBOutlet weak var mapView: MKMapView!

    //Bottom Search
    let searchView = JKBottomSearchView()
    private var currentLocalSearch: MKLocalSearch?


    //Outlets
    @IBOutlet weak var tempLabel: EFCountingLabel!
    @IBOutlet weak var maxtempLabel: EFCountingLabel!
    @IBOutlet weak var mintempLabel: EFCountingLabel!
    @IBOutlet weak var countryLabel: UILabel!
    
    
    typealias CompletionHandler = () -> Void

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        self.navigationItem.titleView = UIImageView(image:UIImage(named: "logo"))
        self.navigationItem.title = "Weather Demo App"
        
        self.ref = Database.database().reference()

        view.addSubview(searchView)
        searchView.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        searchView.dataSource = self
        searchView.delegate = self
        self.customizeSearch(searchView: searchView)
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
        
        
        self.setupTemperatureLabel()
        
        self.fetchLocationHistory(compHandler: {
            self.matchingItems = self.previewItems
            self.searchView.tableView.reloadData()
        })
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardWillShow(notification: Notification) {
        if let keyboardHeight = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height {
            self.searchView.minimalYPosition = UIScreen.main.bounds.height * 0.45 - keyboardHeight
            self.searchView.toggleExpand(.fullyExpanded, fast: true)
        }
    }
    
    @objc func keyboardWillHide(notification: Notification) {
        self.searchView.minimalYPosition = UIScreen.main.bounds.height * 0.45
        self.searchView.toggleExpand(.middle, fast: true)
    }
    
    func setupTemperatureLabel(){
        self.tempLabel.textColor = .white
        self.mintempLabel.textColor = .white
        self.maxtempLabel.textColor = .white
        self.tempLabel.font = self.tempLabel.font.withSize(50)
        
        //Starting value
        self.tempLabel.textAlignment = .center
        self.mintempLabel.textAlignment = .center
        self.maxtempLabel.textAlignment = .center

        self.tempLabel.countFrom(273.15, to: 273.15)
        self.mintempLabel.countFrom(273.15, to: 273.15)
        self.maxtempLabel.countFrom(273.15, to: 273.15)

        //Convert from Kelvin to Celsius Format
        self.tempLabel.formatBlock = {
            (value) in
            return String(Int(value - 273.15) ) + "°C"
        }
        
        self.maxtempLabel.formatBlock = {
            (value) in
            return String(Int(value - 273.15) ) + "°C"
        }
        
        self.mintempLabel.formatBlock = {
            (value) in
            return String(Int(value - 273.15) ) + "°C"
        }
        //Fetch the temperature of the user's location
        
        if((locationManager.location) != nil){
            
            fetchCityAndCountry(from: locationManager.location!) { city, country, error in
                guard let _ = city, let country = country, error == nil else { return }
                
                self.setupWeatherView(lat: Int((self.locationManager.location?.coordinate.latitude)!),
                                      lon: Int((self.locationManager.location?.coordinate.longitude)!), country: country)
                
            }
        }else{
            print("Error: LocationManage.Location == NIL")
        }
       
    }
    
    func fetchLocationHistory(compHandler: @escaping CompletionHandler) {
        ref.child("Locations").observeSingleEvent(of: .value, with: { (snapshot) in
            self.previewItems.removeAll()
            
            for child in snapshot.children {
                let snap = child as! DataSnapshot
                let value:[String: AnyObject] = snap.value as! [String : AnyObject]
                
                let latitude: Double = value["Latitude"]! as! Double
                let longitude: Double = value["Longitude"]! as! Double
                
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
                
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = value["Text"]! as? String
                mapItem.phoneNumber = value["Country"] as? String
                
                self.previewItems.insert(mapItem, at: 0)
            }

                compHandler()

        })

    }
    
    func customizeSearch(searchView: JKBottomSearchView){
        //Change blur effect. Default nil
        searchView.blurEffect = UIBlurEffect(style: .dark)
        
        //Any non tableView and searchBar customization should be performed on contentView
        searchView.contentView.backgroundColor = .white
        
        //Customizing searchBar
        searchView.barStyle = .black
        searchView.searchBarStyle = .minimal
        searchView.searchBarTintColor = .black
        searchView.placeholder = "City / Country"
        searchView.showsCancelButton = false
        searchView.enablesReturnKeyAutomatically = true
        
        //Customizing searchBar textField
        let textField = searchView.searchBarTextField
        textField.textColor = .black
        
        //Customizing tableView
        //You can access tableView and customize as You like by tableView property
        searchView.tableView.isScrollEnabled = false
        searchView.showsCancelButton = false
        
        //Customizing expansion
        searchView.minimalYPosition = UIScreen.main.bounds.height * 0.45 // distance from top after fully expanding
        searchView.fastExpandingTime = 0.1
        searchView.slowExpandingTime = 0.2
        searchView.toggleExpand(.middle,fast:true) // fast parameter is optional, default falses
    }
    
    
    func setupWeatherView(lat: Int, lon: Int, country: String){
        
        DispatchQueue.main.async {
            self.countryLabel.text = country
        }

        
        APIConnector().getWeatherData(lat: Int(lat), lon: Int(lon), compHandler: { res in
            
            let main = res["main"] as! [String: AnyObject]
            
            DispatchQueue.main.async {
                self.tempLabel.countFrom(self.tempLabel.currentValue(), to: main["temp"] as! CGFloat)
                self.maxtempLabel.countFrom(self.maxtempLabel.currentValue(), to: main["temp_max"] as! CGFloat)
                self.mintempLabel.countFrom(self.mintempLabel.currentValue(), to: main["temp_min"] as! CGFloat)
            }
        })
    }
    
}


extension LandingVC: JKBottomSearchDataSource, JKBottomSearchViewDelegate{
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = false
        currentLocalSearch?.cancel()
        searchBar.isLoading = false
        searchBar.endEditing(true)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentLocalSearch?.cancel()
        guard let searchQuery = searchBar.text, !searchQuery.isEmpty else {
            matchingItems = previewItems
            searchView.tableView.reloadData()
            return
        }
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = searchQuery
        searchRequest.region = mapView.region

        // Perform new search request
        let localSearch = MKLocalSearch(request: searchRequest)
        
        localSearch.start { [weak self] (response, error) in
            guard let strongSelf = self else {
                // View controller was deallocated
                return
            }
            
            guard error == nil else {
                print("[ERROR] Search error: \(String(describing: error))")
                strongSelf.matchingItems = strongSelf.previewItems
                strongSelf.searchView.tableView.reloadData()
                searchBar.isLoading = false
                return
            }
            
            guard let response = response else {
                print("[ERROR] Missing response: \(localSearch)")
                strongSelf.matchingItems = strongSelf.previewItems
                strongSelf.searchView.tableView.reloadData()
                searchBar.isLoading = false
                return
            }
            
            // Display search results
            strongSelf.matchingItems = response.mapItems
            strongSelf.searchView.tableView.reloadData()
            searchBar.isLoading = false
        }
        
        
        currentLocalSearch = localSearch
        searchBar.isLoading = true
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
        searchBar.text?.removeAll()
        self.fetchLocationHistory(compHandler: {
            self.matchingItems = self.previewItems
            self.searchView.tableView.reloadData()
        })
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if((searchView.searchBarTextField.text?.isEmpty)!){
            return "Recent Searches"
        }else{
            return "Results"
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let span = MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
        let region = MKCoordinateRegion(center: matchingItems[indexPath.row].placemark.coordinate, span: span)
        annotation.coordinate = matchingItems[indexPath.row].placemark.coordinate
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotation(annotation)
        mapView.setRegion(region, animated: true)
        searchView.toggleExpand(.fullyCollapsed,fast:true)
        searchView.endEditing(true)
        
        let lat = matchingItems[indexPath.row].placemark.coordinate.latitude
        let lon = matchingItems[indexPath.row].placemark.coordinate.longitude
        let country = matchingItems[indexPath.row].placemark.country ?? matchingItems[indexPath.row].phoneNumber ?? "Unknown"
        
        var toBeDeleted:[String] = []
        ref.child("Locations").queryOrderedByKey().observeSingleEvent(of: .value, with: { (snapshot) in
            var num = Int(snapshot.childrenCount) - 5
            
            if(num >= 0){
                for child in snapshot.children{
                    let snap = child as! DataSnapshot
                    toBeDeleted.append(snap.key)
                    num -= 1
                    if(num < 0){
                        break
                    }
                }
            }
            
            for id in toBeDeleted{
                self.ref.child("Locations").child(id).removeValue()
            }
            self.ref.child("Locations").childByAutoId().setValue(["Text":self.matchingItems[indexPath.row].name!, "Longitude":lon.magnitude, "Latitude": lat.magnitude, "Country": country])
        })
        
        //Fetch Weather Data for new location
        self.setupWeatherView(lat: Int(lat), lon: Int(lon), country: country)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        cell.textLabel?.text = self.matchingItems[indexPath.row].name
        return cell
    }
    
}

extension LandingVC : CLLocationManagerDelegate {
    private func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let span = MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
            let region = MKCoordinateRegion(center: location.coordinate, span: span)
            mapView.setRegion(region, animated: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("error:: (error)")
    }
}
