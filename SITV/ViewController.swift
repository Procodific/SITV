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
        let url = NSURL(string: "http://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer")
        let tiledLayer = AGSTiledMapServiceLayer(URL: url)
        self.mapView.addMapLayer(tiledLayer, withName: "Basemap Tiled Layer")
        
        // Establecer los delegates para escuchar eventos
        self.mapView.layerDelegate = mapView // Eventos de layer
        self.mapView.callout.delegate = mapView // Eventos de callout
        
        self.mapView.getAccessToken() // Conseguir access_token
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder() // Esconder el teclado
        self.mapView.startFunc(searchBar.text!) // Iniciar (Ver clase AGSMapViewController.swift)
    }
    
}

