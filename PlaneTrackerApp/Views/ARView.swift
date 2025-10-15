import ARKit
import SceneKit
import UIKit
import simd

class ARView: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    // Services
    private let backendService = BackendService()
    private let trajectoryPredictor = TrajectoryPredictor()
    private let altitudeFallback = AltitudeFallback()
    
    // Flight data and tracking
    private var currentFlights: [Flight] = []
    private var flightTrajectories: [String: [TrajectoryPoint]] = [:]
    private var flightAnchors: [String: ARAnchor] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // AR visualization
    private var trajectoryNodes: [String: SCNNode] = [:]
    private var flightNodes: [String: SCNNode] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Subscribe to backend service updates
        setupBackendSubscriptions()
        
        // Start flight data updates
        startFlightDataUpdates()
    }
    
    private func setupBackendSubscriptions() {
        // Subscribe to flight updates from backend
        backendService.$flights
            .sink { [weak self] flights in
                self?.currentFlights = flights
                self?.updateFlightTrajectories()
                self?.updateARVisualization()
            }
            .store(in: &cancellables)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    // MARK: - Flight Data Management
    
    private func startFlightDataUpdates() {
        // Fetch initial flight data
        backendService.fetchFlights()
        
        // Start periodic flight data updates (backend handles caching)
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.backendService.fetchFlights()
        }
    }
    
    private func updateFlightTrajectories() {
        // Update trajectories for all flights using backend data
        for flight in currentFlights {
            updateFlightTrajectory(flight)
        }
    }
    
    private func updateFlightTrajectory(_ flight: Flight) {
        // Predict trajectory for the flight
        let trajectory = trajectoryPredictor.predictTrajectory(for: flight)
        flightTrajectories[flight.id] = trajectory
        
        // Filter trajectory for AR view
        let cameraPosition = getCameraPosition()
        let cameraOrientation = getCameraOrientation()
        
        let visibleTrajectory = trajectoryPredictor.calculateTrajectoryForAR(
            flight: flight,
            cameraPosition: cameraPosition,
            cameraOrientation: cameraOrientation
        )
        
        // Update trajectory visualization
        updateTrajectoryVisualization(for: flight.id, trajectory: visibleTrajectory)
    }
    
    // MARK: - AR Visualization
    
    private func updateARVisualization() {
        // Update flight positions and trajectories in AR space
        for flight in currentFlights {
            updateFlightPosition(flight)
            updateTrajectoryVisualization(for: flight.id, trajectory: flightTrajectories[flight.id] ?? [])
        }
    }
    
    private func updateFlightPosition(_ flight: Flight) {
        guard let lat = flight.latitude,
              let lon = flight.longitude else { return }
        
        // Get predicted altitude
        let altitude = altitudeFallback.estimateAltitude(for: flight, with: currentFlights)
        
        // Convert to AR world coordinates
        let worldPosition = convertToARWorldCoordinates(
            latitude: lat,
            longitude: lon,
            altitude: altitude
        )
        
        // Create or update flight node
        let flightNode = getOrCreateFlightNode(for: flight.id)
        flightNode.position = worldPosition
        
        // Add flight information
        addFlightInfoToNode(flightNode, flight: flight)
    }
    
    private func updateTrajectoryVisualization(for flightId: String, trajectory: [TrajectoryPoint]) {
        // Remove existing trajectory
        if let existingNode = trajectoryNodes[flightId] {
            existingNode.removeFromParentNode()
        }
        
        guard !trajectory.isEmpty else { return }
        
        // Create trajectory line
        let trajectoryNode = createTrajectoryNode(trajectory: trajectory)
        trajectoryNodes[flightId] = trajectoryNode
        
        // Add to scene
        sceneView.scene.rootNode.addChildNode(trajectoryNode)
    }
    
    private func createTrajectoryNode(trajectory: [TrajectoryPoint]) -> SCNNode {
        let node = SCNNode()
        
        // Create line geometry
        let points = trajectory.map { point in
            convertToARWorldCoordinates(
                latitude: point.latitude,
                longitude: point.longitude,
                altitude: point.altitude
            )
        }
        
        // Create line segments
        for i in 0..<points.count - 1 {
            let lineNode = createLineNode(from: points[i], to: points[i + 1])
            node.addChildNode(lineNode)
        }
        
        return node
    }
    
    private func createLineNode(from: SIMD3<Float>, to: SIMD3<Float>) -> SCNNode {
        let lineNode = SCNNode()
        
        // Calculate distance and direction
        let distance = length(to - from)
        let direction = normalize(to - from)
        
        // Create cylinder geometry for line
        let cylinder = SCNCylinder(radius: 0.1, height: CGFloat(distance))
        cylinder.firstMaterial?.diffuse.contents = UIColor.blue.withAlphaComponent(0.8)
        
        let geometryNode = SCNNode(geometry: cylinder)
        geometryNode.position = (from + to) / 2
        geometryNode.look(at: to, up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, 1))
        
        lineNode.addChildNode(geometryNode)
        return lineNode
    }
    
    // MARK: - Coordinate Conversion
    
    private func convertToARWorldCoordinates(latitude: Double, longitude: Double, altitude: Double) -> SIMD3<Float> {
        // Convert lat/lon/alt to AR world coordinates
        // This is a simplified conversion - in practice, you'd use more sophisticated mapping
        
        let latRad = latitude * .pi / 180
        let lonRad = longitude * .pi / 180
        
        // Convert to local coordinates (simplified)
        let x = Float(altitude * cos(latRad) * cos(lonRad)) / 1000  // Scale down
        let y = Float(altitude * sin(latRad)) / 1000
        let z = Float(altitude * cos(latRad) * sin(lonRad)) / 1000
        
        return SIMD3<Float>(x, y, z)
    }
    
    // MARK: - Camera Information
    
    private func getCameraPosition() -> SIMD3<Float> {
        guard let frame = sceneView.session.currentFrame else {
            return SIMD3<Float>(0, 0, 0)
        }
        
        let transform = frame.camera.transform
        return SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }
    
    private func getCameraOrientation() -> SIMD3<Float> {
        guard let frame = sceneView.session.currentFrame else {
            return SIMD3<Float>(0, 0, -1)
        }
        
        let transform = frame.camera.transform
        return SIMD3<Float>(
            transform.columns.2.x,
            transform.columns.2.y,
            transform.columns.2.z
        )
    }
    
    // MARK: - Node Management
    
    private func getOrCreateFlightNode(for flightId: String) -> SCNNode {
        if let existingNode = flightNodes[flightId] {
            return existingNode
        }
        
        // Create new flight node
        let flightNode = createFlightNode()
        flightNodes[flightId] = flightNode
        sceneView.scene.rootNode.addChildNode(flightNode)
        
        return flightNode
    }
    
    private func createFlightNode() -> SCNNode {
        let node = SCNNode()
        
        // Create aircraft geometry (simplified)
        let aircraftGeometry = SCNBox(width: 0.5, height: 0.2, length: 1.0, chamferRadius: 0.1)
        aircraftGeometry.firstMaterial?.diffuse.contents = UIColor.red
        
        let geometryNode = SCNNode(geometry: aircraftGeometry)
        node.addChildNode(geometryNode)
        
        return node
    }
    
    private func addFlightInfoToNode(_ node: SCNNode, flight: Flight) {
        // Add text label with flight information
        let textGeometry = SCNText(string: flight.callsign, extrusionDepth: 0.1)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.position = SIMD3<Float>(0, 1, 0)  // Above the aircraft
        textNode.scale = SIMD3<Float>(0.1, 0.1, 0.1)
        
        node.addChildNode(textNode)
    }
}
