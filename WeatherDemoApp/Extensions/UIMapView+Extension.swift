//
//  UIMapView+Extension.swift
//  WeatherDemoApp
//
//  Created by Tarek Morsi on 6/12/19.
//  Copyright © 2019 Tarek Morsi. All rights reserved.
//

import UIKit
import MapKit

func fetchCityAndCountry(from location: CLLocation, completion: @escaping (_ city: String?, _ country:  String?, _ error: Error?) -> ()) {
    CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
        completion(placemarks?.first?.locality,
                   placemarks?.first?.country,
                   error)
    }
}
