//
//  USDA.swift
//  RestARant
//
//  Created by Maxwell Hubbard on 10/13/18.
//  Copyright © 2018 Maxwell Hubbard. All rights reserved.
//

import Foundation

class USDA {
    
    static let API_KEY: String! = "CwgyRewjqXjZKpNSBkEXsVKoCOvnvrg42948f6bW"
    
    static var SEARCH_URL: String!
    
    
    static func search(s: String, ds: String, closure: @escaping (_ item: [String: Any]) -> Void) {
        
        
        
        SEARCH_URL = "https://api.nal.usda.gov/ndb/search/?format=json&ds=" + ds.replacingOccurrences(of: " ", with: "%20") + "&q=" + s.replacingOccurrences(of: " ", with: "%20") + "&sort=r&max=50&offset=0&api_key=" + API_KEY
        
        
        
        let session = URLSession.shared
        
        
        let task = session.dataTask(with: URLRequest(url: URL(string: SEARCH_URL)!)) {
            (data, response, error) in
            // check for any errors
            guard error == nil else {
                print("error calling GET")
                print(error!)
                return
            }
            // make sure we got data
            guard let responseData = data else {
                print("Error: did not receive data")
                return
            }
            // parse the result as JSON, since that's what the API provides
            do {
                guard let json = try JSONSerialization.jsonObject(with: responseData, options: [])
                    as? [String: Any] else {
                        print("error trying to convert data to JSON")
                        return
                }
             
                guard let list = json["list"] as? [String: Any] else {
                    print("Could not get list from JSON")
                    return
                }
                
                guard let items = list["item"] as? [[String: Any]] else {
                    print("Could not get items from JSON")
                    return
                }
                
                closure(items[0])
                
            } catch  {
                print("error trying to convert data to JSON")
                return
            }
        }
        task.resume()
       
    }
    
    
    static func getNutrients(id: String, closure: @escaping (_ nutrients: [[String : Any]]) -> Void) {
        let INFO_ID = "https://api.nal.usda.gov/ndb/reports/?ndbno=" + id + "&type=f&format=json&api_key=" + API_KEY
        
        let session = URLSession.shared
        
        
        let task = session.dataTask(with: URLRequest(url: URL(string: INFO_ID)!)) {
            (data, response, error) in
            // check for any errors
            guard error == nil else {
                print("error calling GET")
                print(error!)
                return
            }
            // make sure we got data
            guard let responseData = data else {
                print("Error: did not receive data")
                return
            }
            // parse the result as JSON, since that's what the API provides
            do {
                guard let json = try JSONSerialization.jsonObject(with: responseData, options: [])
                    as? [String: Any] else {
                        print("error trying to convert data to JSON")
                        return
                }
                
                
          
                guard let list = json["report"] as? [String: Any] else {
                    print("Could not get report from JSON")
                    return
                }
                
                guard let items = list["food"] as? [String: Any] else {
                    print("Could not get food from JSON")
                    return
                }
                
                guard let nutrients = items["nutrients"] as? [[String: Any]] else {
                    print("Could not get nutrients from JSON")
                    return
                }
                
                closure(nutrients)
                
            
                
            } catch  {
                print("error trying to convert data to JSON")
                return
            }
        }
        task.resume()
    }
}
