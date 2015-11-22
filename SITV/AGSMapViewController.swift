//
//  AGSMapViewController.swift
//  SITV
//
//  Created by Eric García on 04/08/15.
//  Copyright (c) 2015 Eric García. All rights reserved.
//

import UIKit
import ArcGIS
import GoogleMaps

class AGSMapViewController: AGSMapView, AGSMapViewLayerDelegate, AGSLocatorDelegate, AGSCalloutDelegate, AGSRouteTaskDelegate, UITableViewDataSource, UITableViewDelegate {

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */
    
    var queue:NSOperationQueue! // Ejecuta el servicio web en background
    var access_token: NSString! // Access_token a obtener de la aplicación ArcGIS
    
    var showAllResults : Bool = true
    var firstGraphic : Bool = true
    
    var whichTable : Int!
    
    // OUTLETS DEL UIVIEW
    @IBOutlet weak var directionsLabel: UILabel!
    @IBOutlet weak var prevBtn: UIBarButtonItem!
    @IBOutlet weak var nextBtn: UIBarButtonItem!
    @IBOutlet weak var routeButton: UIButton!
    @IBOutlet weak var clearRouteButton: UIButton!
    @IBOutlet weak var originSearchBar: UISearchBar!
    @IBOutlet weak var destinationSearchBar: UISearchBar!
    @IBOutlet weak var originTableView: UITableView!
    @IBOutlet weak var destinationTableView: UITableView!
    
    // GOOGLE MAPS
    var lugares = [Int: [String]]()
    
    var lookupAddressResults: Dictionary<NSObject, AnyObject>! // origen
    var fetchedFormattedAddress: String! // origen
    var fetchedAddressLongitude: Double! // origen
    var fetchedAddressLatitude: Double! // origen
    
    var originCoordinate : CLLocationCoordinate2D!
    
    var destinationLookupAddressResults: Dictionary<NSObject, AnyObject>! // destino
    var destinationFetchedFormattedAddress: String! // destino
    var destinationFetchedAddressLongitude: Double! // destino
    var destinationFetchedAddressLatitude: Double! // destino
    
    var destinationCoordinate : CLLocationCoordinate2D!

    // ARCGIS
    var graphicLayer: AGSGraphicsLayer! // Layer de todos los gráficos
    
    // Elementos de rutas
    var routeTask: AGSRouteTask!
    var routeResult: AGSRouteResult!
    var currentDirectionGraphic: AGSDirectionGraphic!
    
    func placeAutocomplete(text: String, whichBar: Int) {
    
        let filter = GMSAutocompleteFilter()
        let topLeftCorner = CLLocationCoordinate2D(latitude: 18.490028574, longitude: -99.140625)
        let bottomRightCorner = CLLocationCoordinate2D(latitude: 20.0868885056, longitude: -97.0751953125)
        let bounds = GMSCoordinateBounds(coordinate: topLeftCorner, coordinate: bottomRightCorner)

        filter.type = GMSPlacesAutocompleteTypeFilter.NoFilter
        
        let placesClient = GMSPlacesClient()
        
        if !text.isEmpty {
            placesClient.autocompleteQuery(text, bounds: bounds, filter: filter, callback: { (results, error: NSError?) -> Void in
                
                if let error = error {
                    print("Autocomplete error \(error)")
                }
                
                self.lugares = [Int: [String]]()
                var index = 0
                for result in results! {
                    if let result = result as? GMSAutocompletePrediction {
                        self.lugares[index++] = [result.placeID, result.attributedFullText.string]
                    }
                }
                
                if whichBar == 1 {
                    self.destinationTableView.hidden = true;
                    self.originTableView.hidden = false;
                    self.originTableView.reloadData()
                }
                else {
                    self.originTableView.hidden = true;
                    self.destinationTableView.hidden = false;
                    self.destinationTableView.reloadData()
                }
                
            })
        }
    }
    
    // Al cargar el mapa
    func mapViewDidLoad(mapView: AGSMapView!) {
        mapView.locationDisplay.startDataSource() // Muestra ubicación actual
    }
    
    // Ejecución del web service
    func getAccessToken() {
        // Configuración del mensaje POST
        let url = NSURL(string: "https://www.arcgis.com/sharing/rest/oauth2/token/")
        let params = [
            "client_id": "Bw3KiMdULPvUEStB",
            "client_secret": "742dbc21626b40b49b6425f136454b6a",
            "grant_type": "client_credentials"
        ]
        
        let jsonOp = AGSJSONRequestOperation(URL: url, queryParameters: params)
        jsonOp.target = self;
        jsonOp.action = "operation:didSucceedWithResponse:"
        jsonOp.errorAction = "operation:didFailWithError:"
        
        // Ejecuta en background
        queue = NSOperationQueue()
        self.queue.addOperation(jsonOp)
    }
    
    // Exito del web service
    func operation(op:NSOperation, didSucceedWithResponse json:NSDictionary) {
        access_token = json["access_token"] as! NSString // Obtiene el token del JSON
        print("Got token: \(access_token)") // Muestra el access_token
        self.queue.cancelAllOperations() // Deja de ejecutarla en background
    }
    
    // Error del web service
    func operation(op:NSOperation, didFailWithError error:NSError) {
        print("Error at web service: \(error)")
        self.queue.cancelAllOperations() // Deja de ejecutarla en background
    }
    
    // Función inicial
    func startFunc() {
        // Si no hay un layer
        if self.graphicLayer == nil {
            self.graphicLayer = AGSGraphicsLayer() // Layer que tendrá los resultados de geolocalización
            addMapLayer(self.graphicLayer, withName:"Results") // Agrega el layer
            
            // Crea un MarkerSymbol
            let pushpin = AGSPictureMarkerSymbol(imageNamed: "BluePushpin.png")
            pushpin.offset = CGPointMake(9, 16)
            pushpin.leaderPoint = CGPointMake(-9, 11)
            
            let renderer = AGSSimpleRenderer(symbol: pushpin) // Renderer con el marker
            self.graphicLayer.renderer = renderer // Asigna el renderer al layer
        }
    }
    
    // Consigue los Details de un Place (Google)
    func getPlaceDetails(placeID: String) {
        
        let placesClient = GMSPlacesClient()
        
        placesClient.lookUpPlaceID(placeID, callback: { (place: GMSPlace?, error: NSError?) -> Void in
            if let error = error {
                print("lookup place id query error: \(error.localizedDescription)")
                return
            }
            
            if let place = place {
                
                if self.whichTable == 1 {
                    self.originCoordinate = place.coordinate
                }
                else {
                    self.destinationCoordinate = place.coordinate
                }
                
                if self.originCoordinate != nil && self.destinationCoordinate != nil {
                    self.startFunc();
                    self.routeButton.enabled = true
                }
                
            } else {
                UIAlertView(title: "Error", message: "No se pudo encontrar el lugar", delegate: nil, cancelButtonTitle: "OK").show()
            }
        })
    }
    
    // Muestra la dirección i-esima
    func displayDirectionForIndex(index:Int) {
        self.graphicLayer.removeGraphic(self.currentDirectionGraphic) // Quitar la dirección anterior
        
        let directions = self.routeResult.directions as AGSDirectionSet // Obtener la dirección
        self.currentDirectionGraphic = directions.graphics[index] as! AGSDirectionGraphic // Asignar la dirección
        
        // Resaltar la dirección con otro symbol
        let cs = AGSCompositeSymbol()
        let sls1 = AGSSimpleLineSymbol()
        sls1.color = UIColor.whiteColor()
        sls1.style = .Solid
        sls1.width = 8
        cs.addSymbol(sls1)
        let sls2 = AGSSimpleLineSymbol()
        sls2.color = UIColor.redColor()
        sls2.style = .Dash
        sls2.width = 4
        cs.addSymbol(sls2)
        self.currentDirectionGraphic.symbol = cs
        self.graphicLayer.addGraphic(self.currentDirectionGraphic)
        
        self.directionsLabel.text = self.currentDirectionGraphic.text // Texto con dirección al label
        
        // Zoom a la dirección actual (1.3 de zoom)
        let env = self.currentDirectionGraphic.geometry.envelope.mutableCopy() as! AGSMutableEnvelope
        env.expandByFactor(1.3)
        self.zoomToEnvelope(env, animated: true)
        
        // Ver si se deshabilitar los botones
        if index >= self.routeResult.directions.graphics.count - 1 {
            self.nextBtn.enabled = false
        }
        else {
            self.nextBtn.enabled = true
        }
        
        if index > 0 {
            self.prevBtn.enabled = true
        }
        else {
            self.prevBtn.enabled = false
        }
    }
    
    // Traza ruta dado un destino
    func routeTo() {
        let params = AGSRouteTaskParameters() // Parametros del RouteTask
        
        // Ambos puntos se obtienen como Stops, y debe cambiarse
        // su sistema de latitud/longitud por el wgs84SpatialReference
        
        // Segundo punto
        let first_point = AGSPoint(x: originCoordinate.longitude, y: originCoordinate.latitude, spatialReference: AGSSpatialReference.wgs84SpatialReference())
        
        // Primer punto
        let second_point = AGSPoint(x: destinationCoordinate.longitude, y: destinationCoordinate.latitude, spatialReference: AGSSpatialReference.wgs84SpatialReference())
        
        // Si no hay un routeTask
        if self.routeTask == nil {
            let serviceURL = "http://route.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World/solve?token=\(self.access_token)&stops=\(first_point.x),\(first_point.y);\(second_point.x),\(second_point.y)&directionsLanguage=es&f=json"
            
            print(serviceURL)
            
            self.routeTask = AGSRouteTask(URL: NSURL(string: serviceURL)) // RouteTask con el servicio
            self.routeTask.delegate = self // Delegate del routeTask
        }
        
        // Regresar toda la ruta
        params.returnRouteGraphics = true
        
        // Regresar direcciones de vueltas
        params.returnDirections = true
        
        // Evitar ordenamiento de stops
        params.findBestSequence = false
        params.preserveFirstStop = true
        params.preserveLastStop = true
        
        // ensure the graphics are returned in our maps spatial reference
        params.outSpatialReference = self.spatialReference
        
        params.ignoreInvalidLocations = false // Ignorar stops inválidos
        self.routeTask.solveWithParameters(params) // Ejecutar el servicio
    }
    
    // Ejecución correcta del routeTask
    func routeTask(routeTask: AGSRouteTask!, operation op: NSOperation!, didSolveWithResult routeTaskResult: AGSRouteTaskResult!) {
        
        self.directionsLabel.text = "Ruta calculada" // Texto del label
        self.routeButton.enabled = false
        self.clearRouteButton.enabled = true
        
        // Remover la ruta trazada, si hay una
        if self.routeResult != nil {
            self.graphicLayer.removeGraphic(self.routeResult.routeGraphic)
        }
        
        // Si hay resultados de rutas
        if routeTaskResult.routeResults != nil {
            
            // Se sabe que solo hay 1 ruta
            self.routeResult = routeTaskResult.routeResults[0] as? AGSRouteResult // Obtiene ruta [0]
            
            // Si no se ha trazado la ruta
            if self.routeResult != nil && self.routeResult.routeGraphic != nil {
                
                // Se mostrará la ruta con la línea siguiente
                let yellowLine = AGSSimpleLineSymbol(color: UIColor.orangeColor(), width: 8.0)
                self.routeResult.routeGraphic.symbol = yellowLine
                
                // Se agrega el graphic al layer
                self.graphicLayer.addGraphic(self.routeResult.routeGraphic)
                
                self.nextBtn.enabled = true // Enable del botón next para pasar las direcciones
                self.prevBtn.enabled = false
                self.currentDirectionGraphic = nil
                self.zoomToGeometry(self.routeResult.routeGraphic.geometry, withPadding: 100, animated: true)
            }
        }
        // No hubo rutas
        else {
            UIAlertView(title: "Sin rutas", message: "No se encontraron rutas", delegate: nil, cancelButtonTitle: "OK").show()
        }
    }
    
    // TableView DataSource and Delegate
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "autocompleteCell";
        var cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier)
        
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: cellIdentifier)
        }
        
        cell?.textLabel?.text = lugares[indexPath.row]![1]
        
        return cell!;
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return lugares.count;
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let placeID = lugares[indexPath.row]![0];
        
        if tableView == originTableView {
            whichTable = 1
            self.originSearchBar.text = lugares[indexPath.row]![1]
            self.originSearchBar.resignFirstResponder()
            self.originTableView.hidden = true
        }
        else {
            whichTable = 2
            self.destinationSearchBar.text = lugares[indexPath.row]![1]
            self.destinationSearchBar.resignFirstResponder()
            self.destinationTableView.hidden = true
        }
        
        self.getPlaceDetails(placeID)
    }
    
    // Botón consultar ruta
    @IBAction func routeButtonClicked(sender: AnyObject) {
        if originSearchBar.text == "" || destinationSearchBar.text == "" {
            UIAlertView(title: "Faltan campos", message: "Ingrese un origen y destino", delegate: nil, cancelButtonTitle: "OK").show()
        }
        else {
            self.routeTo() // Trazar ruta, se pasa el AGSGeometry
        }
    }
    
    @IBAction func clearRouteButtonClicked(sender: AnyObject) {
        self.originSearchBar.text = ""
        self.destinationSearchBar.text = ""
        self.originCoordinate = nil
        self.destinationCoordinate = nil
        self.graphicLayer.removeAllGraphics()
        
        self.clearRouteButton.enabled = false
    }
    
    // Botón prev
    @IBAction func prevBtnClicked(sender: AnyObject) {
        var index = 0
        
        if self.currentDirectionGraphic != nil {
            if let currentIndex = (self.routeResult.directions.graphics as! [AGSDirectionGraphic]).indexOf(self.currentDirectionGraphic) {
                index = currentIndex - 1
            }
        }
        self.displayDirectionForIndex(index)
    }
    
    // Botón next
    @IBAction func nextBtnClicked(sender: AnyObject) {
        var index = 0
        
        if self.currentDirectionGraphic != nil {
            if let currentIndex = (self.routeResult.directions.graphics as! [AGSDirectionGraphic]).indexOf(self.currentDirectionGraphic) {
                index = currentIndex + 1
            }
        }
        self.displayDirectionForIndex(index)
    }
}
