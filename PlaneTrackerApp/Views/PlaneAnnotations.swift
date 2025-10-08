import ARKit
import SceneKit

class PlaneAnnotations: SCNNode {
    
    var flight: Flight?
    
    init(flight: Flight) {
        self.flight = flight
        super.init()
        setupAnnotation()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupAnnotation() {
        // Create a simple sphere to represent the plane
        let sphere = SCNSphere(radius: 0.1)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        sphere.materials = [material]
        
        let sphereNode = SCNNode(geometry: sphere)
        addChildNode(sphereNode)
        
        // Add text label
        let text = SCNText(string: flight?.callsign ?? "Unknown", extrusionDepth: 0.1)
        text.font = UIFont.systemFont(ofSize: 0.1)
        let textNode = SCNNode(geometry: text)
        textNode.position = SCNVector3(0, 0.2, 0)
        addChildNode(textNode)
    }
    
    func updatePosition(with coordinates: Coordinates) {
        // Update the position based on flight coordinates
        // This would convert lat/lon/alt to ARKit world coordinates
        position = SCNVector3(coordinates.x, coordinates.y, coordinates.z)
    }
}
