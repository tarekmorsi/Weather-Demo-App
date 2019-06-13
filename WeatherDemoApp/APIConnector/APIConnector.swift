
//
//  Connector.swift
//  WeatherDemoApp
//
//  Created by Tarek Morsi on 6/11/19.
//  Copyright © 2019 Tarek Morsi. All rights reserved.
//

import Foundation

class APIConnector: NSObject{
    
    let API_KEY: String = "b2779662cc5f1772ded4fd1276551d3d"
    let BASE_URL:String = "http://api.openweathermap.org/data/2.5/"
    
    typealias CompletionHandler = (_ res: Dictionary<String, AnyObject>) -> Void

    func getWeatherData(lat: Int, lon: Int, compHandler: @escaping CompletionHandler) {
        
        let url = BASE_URL + "weather?lat=" + String(lat) + "&lon=" + String(lon) + "&appid=" + API_KEY        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            do {
                if(data != nil){
                    let json = try JSONSerialization.jsonObject(with: data!) as! Dictionary<String, AnyObject>
                    compHandler(json)
                }else{
                    print("error")
                }
            } catch {
            }
        })
        task.resume()
    }
    
}
