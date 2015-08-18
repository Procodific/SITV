//
//  AGSMapViewController.swift
//  SITV
//
//  Created by Eric García on 04/08/15.
//  Copyright (c) 2015 Eric García. All rights reserved.
//

import UIKit
import ArcGIS

class AGSMapViewController: AGSMapView, AGSMapViewLayerDelegate, AGSLocatorDelegate, AGSCalloutDelegate, AGSRouteTaskDelegate {

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */
    
    var queue:NSOperationQueue! // Ejecuta el servicio web en background
    var access_token: NSString! // Access_token a obtener de la aplicación ArcGIS
    
    // OUTLETS DEL UIVIEW
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var directionsLabel: UILabel!
    @IBOutlet weak var prevBtn: UIBarButtonItem!
    @IBOutlet weak var nextBtn: UIBarButtonItem!
    
    // Elementos para geolocalización y rutas de dirección
    var graphicLayer: AGSGraphicsLayer!
    var locator: AGSLocator!
    var calloutTemplate: AGSCalloutTemplate!
    var routeTask: AGSRouteTask!
    var routeResult: AGSRouteResult!
    var currentDirectionGraphic: AGSDirectionGraphic!
    
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
        println("Got token: \(access_token)") // Muestra el access_token
        self.queue.cancelAllOperations() // Deja de ejecutarla en background
    }
    
    // Error del web service
    func operation(op:NSOperation, didFailWithError error:NSError) {
        println("Error at web service: \(error)")
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
        else { // Existe un layer!
            self.graphicLayer.removeAllGraphics() // Limpia el layer ( elimina los resultados anteriores)
        }
        
        // Si no hay un locator
        if self.locator == nil {
            // Crear el locator desde REST ArcGIS
            // y asignar el delegate para escuchar eventos
            
            // URL del servicio de geolocalización
            let url = NSURL(string: "http://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer")
            self.locator = AGSLocator(URL: url) // Locator con la url del servicio
            self.locator.delegate = self // Asigna el delegate del locator
        }
        
        // Parametros del locator (desde donde buscar)
        let params = AGSLocatorFindParameters()
        params.text = searchBar.text
        params.outFields = ["*"]
        params.outSpatialReference = self.spatialReference
        params.location = AGSPoint(x: 0, y: 0, spatialReference: nil)
        
        self.locator.findWithParameters(params) // Ejecución del servicio geolocalización en background
    }
    
    // Ejecución correcta del locator
    func locator(locator: AGSLocator!, operation op: NSOperation!, didFind results: [AnyObject]!) {
        
        // Si hay resultados
        if results != nil || results.count > 0 {
            
            // Crea un calloutTemplate sino existe ya uno
            if self.calloutTemplate == nil {
                self.calloutTemplate = AGSCalloutTemplate()
                self.calloutTemplate.titleTemplate = "${Match_addr}"
                self.calloutTemplate.detailTemplate = "${DisplayY}\u{00b0} ${DisplayX}\u{00b0}"
                // Assign the callout template to the layer so that all graphics within this layer
                // display their information in the callout in the same manner
                self.graphicLayer.calloutDelegate = self.calloutTemplate
            }
            
            // Agrega el grafico de cada resultado
            for result in results as! [AGSLocatorFindResult] {
                self.graphicLayer.addGraphic(result.graphic)
            }
            
            // Zoom de los resultados
            let extent = self.graphicLayer.fullEnvelope.mutableCopy() as! AGSMutableEnvelope
            extent.expandByFactor(2.0)
            zoomToEnvelope(extent, animated: true)
        }
        // No hay resultados
        else {
            UIAlertView(title: "Sin resultados", message: "No se encontraron resultados", delegate: nil, cancelButtonTitle: "OK").show()
        }
    }
    
    // Evento click en "i" (botón), accessory de los graphics
    func didClickAccessoryButtonForCallout(callout: AGSCallout!) {
        let graphic = callout.representedObject as! AGSGraphic // Obtiene el objeto del click
        let destinationLocation = graphic.geometry // Conseguir el AGSGeometry
        self.routeTo(destinationLocation) // Trazar ruta, se pasa el AGSGeometry
    }
    
    // Funcion que traza ruta dado un destino
    func routeTo(destination: AGSGeometry) {
        let params = AGSRouteTaskParameters() // Parametros del RouteTask
        
        // Ambos puntos se obtienen como Stops, y debe cambiarse
        // su sistema de latitud/longitud por el wgs84SpatialReference
        
        // Primer punto
        let lastStop = AGSStopGraphic(geometry: destination, symbol: nil, attributes: nil)
        let second_point = AGSGeometryEngine.defaultGeometryEngine().projectGeometry(lastStop.geometry, toSpatialReference: AGSSpatialReference.wgs84SpatialReference()) as! AGSPoint
        
        // Segundo punto
        let firstStop = AGSStopGraphic(geometry: self.locationDisplay.mapLocation(), symbol: nil, attributes: nil)
        let first_point = AGSGeometryEngine.defaultGeometryEngine().projectGeometry(firstStop.geometry, toSpatialReference: AGSSpatialReference.wgs84SpatialReference()) as! AGSPoint
    
        params.setStopsWithFeatures([firstStop, lastStop])
        
        // Si no hay un routeTask
        if self.routeTask == nil {
            let serviceURL = "http://route.arcgis.com/arcgis/rest/services/World/Route/NAServer/Route_World/solve?token=\(self.access_token)&stops=\(first_point.x),\(first_point.y);\(second_point.x),\(second_point.y)&directionsLanguage=es&f=json"
            
            println(serviceURL)
            
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
                
                return
            }
        }
        
        // No hubo rutas
        UIAlertView(title: "Sin rutas", message: "No se encontraron rutas", delegate: nil, cancelButtonTitle: "OK").show()
        
    }
    
    // Botón prev
    @IBAction func prevBtnClicked(sender: AnyObject) {
        var index = 0
        
        if self.currentDirectionGraphic != nil {
            if let currentIndex = find(self.routeResult.directions.graphics as! [AGSDirectionGraphic], self.currentDirectionGraphic) {
                index = currentIndex - 1
            }
        }
        self.displayDirectionForIndex(index)
    }
    
    // Botón next
    @IBAction func nextBtnClicked(sender: AnyObject) {
        var index = 0
        
        if self.currentDirectionGraphic != nil {
            if let currentIndex = find(self.routeResult.directions.graphics as! [AGSDirectionGraphic], self.currentDirectionGraphic) {
                index = currentIndex + 1
            }
        }
        self.displayDirectionForIndex(index)
    }
    
    // Función de mostrar la dirección i-esima
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
}
