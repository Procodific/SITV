//
//  ViewController.swift
//  SITV
//
//  Created by Eric García on 01/08/15.
//  Copyright (c) 2015 Eric García. All rights reserved.
//

import UIKit
import ArcGIS

class ViewController: UIViewController, UISearchBarDelegate {
    
    @IBOutlet var mapView: AGSMapViewController!
    @IBOutlet weak var originSearchBar: UISearchBar!
    @IBOutlet weak var destinationSearchBar: UISearchBar!
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Agregar un mapa base tiled
        let url = NSURL(string: "http://services.arcgisonline.com/arcgis/rest/services/World_Street_Map/MapServer")
        //let url = NSURL(string: "http://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer")
        let tiledLayer = AGSTiledMapServiceLayer(URL: url)
        self.mapView.addMapLayer(tiledLayer, withName: "Basemap Tiled Layer")
        
        // Tablas
        self.mapView.originTableView.scrollEnabled = true
        self.mapView.originTableView.hidden = true
        self.mapView.destinationTableView.scrollEnabled = true
        self.mapView.destinationTableView.hidden = true
        
        
        // Establecer los delegates para escuchar eventos
        self.mapView.layerDelegate = mapView // Eventos de layer
        self.mapView.callout.delegate = mapView // Eventos de callout
        self.originSearchBar.delegate = self
        self.destinationSearchBar.delegate = self
        self.mapView.originTableView.delegate = mapView
        self.mapView.originTableView.dataSource = mapView
        self.mapView.destinationTableView.delegate = mapView
        self.mapView.destinationTableView.dataSource = mapView
        
        self.mapView.getAccessToken() // Conseguir access_token de ArcGIS
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        if searchBar == self.originSearchBar {
            destinationSearchBar.resignFirstResponder()
        }
    }
    
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        if searchBar == self.mapView.originSearchBar {
            self.mapView.placeAutocomplete(searchBar.text!, whichBar: 1)
        }
        else {
            self.mapView.placeAutocomplete(searchBar.text!, whichBar: 2)
        }
    }
    
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar == self.mapView.originSearchBar {
            self.mapView.placeAutocomplete(searchBar.text!, whichBar: 1)
        }
        else {
            self.mapView.placeAutocomplete(searchBar.text!, whichBar: 2)
        }
    }
    
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        if searchBar == self.mapView.originSearchBar {
            self.mapView.originTableView.hidden = true
        }
        else {
            self.mapView.destinationTableView.hidden = true
        }
    }
}

