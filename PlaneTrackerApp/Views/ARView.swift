import ARKit
import SceneKit
import UIKit
import simd
import Combine
import CoreLocation

class ARView: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {
    
    var sceneView: ARSCNView!
    
    // Services
    private let flightService = OpenSkyService()
    private let trajectoryPredictor = TrajectoryPredictor()
    private let altitudeFallback = AltitudeFallback()
    private let locationManager = CLLocationManager()
    
    // Location tracking
    private var currentLocation: CLLocation?
    
    // Flight data and tracking
    private var currentFlights: [Flight] = []
    private var flightTrajectories: [String: [TrajectoryPoint]] = [:]
    private var flightAnchors: [String: ARAnchor] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // AR visualization
    private var trajectoryNodes: [String: SCNNode] = [:]
    private var flightNodes: [String: SCNNode] = [:]
    
    // Compass overlay
    private var compassView: UIView!
    private var compassLabels: [UILabel] = []
    private var headingIndicator: UIView!
    
    // Flight detail popup
    private var flightDetailView: UIView?
    private var shuffledFlights: [Flight] = []
    private var currentShuffleIndex = 0
    private var popupCompass: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("🚀🚀🚀 ARView viewDidLoad called!")
        
        // Create ARSCNView programmatically
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)
        NSLog("✅ ARSCNView created and added to view")
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        NSLog("✅ Scene created and configured")
        
        // Subscribe to backend service updates
        setupBackendSubscriptions()
        
        // Start flight data updates
        startFlightDataUpdates()
        
        // Setup compass overlay
        setupCompassOverlay()
        
        // Setup location services
        setupLocationServices()
    }
    
    private func setupLocationServices() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        NSLog("📍 Location services requested")
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        NSLog("📍 Got location: lat=\(location.coordinate.latitude), lon=\(location.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("⚠️ Location error: \(error.localizedDescription)")
    }
    
    private func setupCompassOverlay() {
        // Create compass view
        compassView = UIView(frame: CGRect(x: 0, y: 100, width: 120, height: 120))
        compassView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        compassView.layer.cornerRadius = 60
        compassView.layer.borderWidth = 2
        compassView.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        
        // Add rotatable ring for NSEW directions
        let ringContainer = UIView(frame: compassView.bounds)
        ringContainer.backgroundColor = UIColor.clear
        ringContainer.layer.cornerRadius = 60
        ringContainer.tag = 999 // Tag for rotation
        compassView.addSubview(ringContainer)
        
        // Add cardinal directions that will rotate
        let directions = ["N", "E", "S", "W"]
        let angles: [CGFloat] = [0, 90, 180, 270]
        
        for (index, direction) in directions.enumerated() {
            let label = UILabel()
            label.text = direction
            label.textColor = .white
            label.font = UIFont.boldSystemFont(ofSize: 16)
            label.textAlignment = .center
            label.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            
            let angle = angles[index] * .pi / 180
            let radius: CGFloat = 42
            label.center = CGPoint(
                x: 60 + radius * cos(angle),
                y: 60 + radius * sin(angle)
            )
            
            ringContainer.addSubview(label)
            compassLabels.append(label)
        }
        
        // Add fixed center arrow (always points up = north)
        headingIndicator = UIView(frame: CGRect(x: 50, y: 50, width: 20, height: 20))
        headingIndicator.backgroundColor = .clear
        
        // Create arrow shape pointing DOWN (will be rotated 180 degrees to point up)
        let arrowPath = UIBezierPath()
        arrowPath.move(to: CGPoint(x: 10, y: 0))    // Top point
        arrowPath.addLine(to: CGPoint(x: 0, y: 12)) // Left point
        arrowPath.addLine(to: CGPoint(x: 4, y: 12))  // Left notch
        arrowPath.addLine(to: CGPoint(x: 4, y: 20))  // Bottom
        arrowPath.addLine(to: CGPoint(x: 16, y: 20)) // Bottom
        arrowPath.addLine(to: CGPoint(x: 16, y: 12)) // Right notch
        arrowPath.addLine(to: CGPoint(x: 20, y: 12)) // Right point
        arrowPath.close()
        
        let arrowLayer = CAShapeLayer()
        arrowLayer.path = arrowPath.cgPath
        arrowLayer.fillColor = UIColor.systemRed.cgColor
        headingIndicator.layer.insertSublayer(arrowLayer, at: 0)
        
        compassView.addSubview(headingIndicator)
        
        view.addSubview(compassView)
        NSLog("✅ Compass overlay created")
        
        // Add shuffle button
        let shuffleButton = UIButton(frame: CGRect(x: view.bounds.width - 160, y: 100, width: 140, height: 44))
        shuffleButton.setTitle("Shuffle Flight", for: .normal)
        shuffleButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        shuffleButton.layer.cornerRadius = 22
        shuffleButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        shuffleButton.addTarget(self, action: #selector(shuffleFlight), for: .touchUpInside)
        view.addSubview(shuffleButton)
        
        // Add tap gesture to AR view for flight detail popup
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleARTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Start updating compass heading
        startCompassUpdates()
    }
    
    private func startCompassUpdates() {
        // Use AR session to update compass heading
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCompassHeading()
            self?.rotateCompassDots()
            
            // Update popup compass if active
            if let flights = self?.shuffledFlights,
               flights.indices.contains(self?.currentShuffleIndex ?? 0),
               let flight = flights.indices.contains(self?.currentShuffleIndex ?? 0) ? flights[self!.currentShuffleIndex] : nil,
               let lat = flight.latitude, let lon = flight.longitude {
                self?.updatePopupCompass(flightLat: lat, flightLon: lon)
            }
        }
    }
    
    private func addMockOverheadFlight() {
        // Create a mock flight directly overhead
        let mockFlight = Flight(
            id: "mock-overhead",
            callsign: "TEST",
            originCountry: "United States",
            timePosition: Int(Date().timeIntervalSince1970),
            lastContact: Int(Date().timeIntervalSince1970),
            longitude: currentLocation?.coordinate.longitude ?? -122.4098,
            latitude: currentLocation?.coordinate.latitude ?? 37.8087,
            baroAltitude: 3048.0, // 10,000 feet
            onGround: false,
            velocity: 250.0,
            trueTrack: 90.0,
            verticalRate: 0.0,
            sensors: nil,
            geoAltitude: 3070.0,
            squawk: "1200",
            spi: false,
            positionSource: 0
        )
        
        currentFlights.append(mockFlight)
    }
    
    private func rotateCompassDots() {
        // Flight dots should NOT rotate - they stay in their absolute position
        // as you rotate your phone, the dot moves around the compass to show
        // the relative direction to locate the flight
        // No rotation needed - dots are already in correct absolute position
    }
    
    private func inferAirline(from callsign: String) -> String {
        let trimmed = callsign.trimmingCharacters(in: .whitespaces).uppercased()
        
        // Map common airline codes to names
        let airlinePrefixes: [String: String] = [
            "UAL": "United Airlines",
            "SWA": "Southwest Airlines",
            "AAL": "American Airlines",
            "DAL": "Delta Air Lines",
            "ASA": "Alaska Airlines",
            "JBU": "JetBlue Airways",
            "NKS": "Spirit Airlines",
            "FFT": "Frontier Airlines",
            "FDX": "FedEx",
            "UPS": "UPS Airlines",
            "EJA": "Executive Jet Aviation",
            "N": "Private/Civil Aviation" // N-prefix for US registered aircraft
        ]
        
        // Check if callsign starts with known prefix
        for (prefix, airline) in airlinePrefixes {
            if trimmed.hasPrefix(prefix) {
                return airline
            }
        }
        
        // If it starts with N, it's a US registered aircraft
        if trimmed.hasPrefix("N") {
            return "US Registered Aircraft"
        }
        
        return "Unknown Airline"
    }
    
    private func updateCompassHeading() {
        guard let frame = sceneView.session.currentFrame else { return }
        
        // Get device orientation
        let cameraTransform = frame.camera.transform
        let forward = SIMD3<Float>(cameraTransform.columns.2.x, 0, cameraTransform.columns.2.z)
        let heading = atan2(forward.x, forward.z) * 180 / .pi
        
        // The arrow should point north (always up), and NSEW should rotate to compensate
        // So we rotate NSEW by the heading amount
        if let ringContainer = compassView.viewWithTag(999) {
            UIView.animate(withDuration: 0.2) {
                ringContainer.transform = CGAffineTransform(rotationAngle: CGFloat(heading) * .pi / 180)
            }
        }
    }
    
    @objc private func handleARTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        
        // Hit test to see if we tapped on a plane
        let hitResults = sceneView.hitTest(location, options: [
            .categoryBitMask: 1, // Search for all nodes
            .ignoreHiddenNodes: true
        ])
        
        // Check if we hit a flight node
        for result in hitResults {
            var node = result.node
            
            // Navigate up to find the parent flight node
            while node.parent != nil {
                if let flightId = getFlightId(for: node) {
                    // Found the flight node - show details
                    if let flight = currentFlights.first(where: { $0.id == flightId }) {
                        showFlightDetail(for: flight)
                        return
                    }
                }
                node = node.parent!
            }
        }
    }
    
    @objc private func shuffleFlight() {
        // Create shuffled list of flights
        shuffledFlights = currentFlights.shuffled()
        currentShuffleIndex = 0
        
        if let firstFlight = shuffledFlights.first {
            showFlightDetail(for: firstFlight)
            
            // Add swipe gesture recognizers to popup
            addSwipeGestures()
        }
    }
    
    private func addSwipeGestures() {
        guard let popup = flightDetailView else { return }
        
        // Remove existing gestures
        popup.gestureRecognizers?.forEach { popup.removeGestureRecognizer($0) }
        
        // Add swipe left to go to next flight
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(swipeToNextFlight))
        swipeLeft.direction = .left
        popup.addGestureRecognizer(swipeLeft)
        
        // Add swipe right to go to previous flight
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(swipeToPreviousFlight))
        swipeRight.direction = .right
        popup.addGestureRecognizer(swipeRight)
    }
    
    @objc private func swipeToNextFlight() {
        guard !shuffledFlights.isEmpty else { return }
        currentShuffleIndex = (currentShuffleIndex + 1) % shuffledFlights.count
        showFlightDetailWithAnimation(for: shuffledFlights[currentShuffleIndex], direction: .left)
        addSwipeGestures()
    }
    
    @objc private func swipeToPreviousFlight() {
        guard !shuffledFlights.isEmpty else { return }
        currentShuffleIndex = (currentShuffleIndex - 1 + shuffledFlights.count) % shuffledFlights.count
        showFlightDetailWithAnimation(for: shuffledFlights[currentShuffleIndex], direction: .right)
        addSwipeGestures()
    }
    
    private func showFlightDetailWithAnimation(for flight: Flight, direction: UISwipeGestureRecognizer.Direction) {
        guard let oldPopup = flightDetailView else {
            showFlightDetail(for: flight)
            return
        }
        
        // Animate old popup out
        let slideOutX: CGFloat = direction == .left ? -view.bounds.width : view.bounds.width
        UIView.animate(withDuration: 0.2, animations: {
            oldPopup.transform = CGAffineTransform(translationX: slideOutX, y: 0)
            oldPopup.alpha = 0
        }) { _ in
            oldPopup.removeFromSuperview()
            
            // Show new popup sliding in from opposite direction
            self.showFlightDetail(for: flight)
            if let newPopup = self.flightDetailView {
                let slideInX: CGFloat = direction == .left ? self.view.bounds.width : -self.view.bounds.width
                newPopup.transform = CGAffineTransform(translationX: slideInX, y: 0)
                newPopup.alpha = 0
                
                UIView.animate(withDuration: 0.2) {
                    newPopup.transform = .identity
                    newPopup.alpha = 1
                }
            }
        }
    }
    
    private func getFlightId(for node: SCNNode) -> String? {
        // Search through flight nodes to find which one contains this node
        for (flightId, flightNode) in flightNodes {
            if node === flightNode || isDescendant(of: node, in: flightNode) {
                return flightId
            }
        }
        return nil
    }
    
    private func isDescendant(of node: SCNNode, in root: SCNNode) -> Bool {
        var currentNode: SCNNode? = node
        while let current = currentNode {
            if current === root {
                return true
            }
            currentNode = current.parent
        }
        return false
    }
    
    private func showFlightDetail(for flight: Flight) {
        // Only dismiss if not in animation
        if let existing = flightDetailView, existing.layer.animationKeys() == nil {
            existing.removeFromSuperview()
        }
        
        // Create popup view
        let popup = UIView(frame: CGRect(x: 20, y: view.bounds.height - 200, width: view.bounds.width - 40, height: 160))
        popup.isUserInteractionEnabled = true
        popup.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        popup.layer.cornerRadius = 16
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.3
        popup.layer.shadowOffset = CGSize(width: 0, height: -2)
        popup.layer.shadowRadius = 8
        
        // Add title (Callsign)
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 16, width: popup.bounds.width - 80, height: 24))
        titleLabel.text = flight.callsign
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = .label
        popup.addSubview(titleLabel)
        
        // Add airline (infer from callsign)
        let airlineLabel = UILabel(frame: CGRect(x: 20, y: 44, width: popup.bounds.width - 40, height: 20))
        airlineLabel.text = inferAirline(from: flight.callsign)
        airlineLabel.font = UIFont.systemFont(ofSize: 14)
        airlineLabel.textColor = .secondaryLabel
        popup.addSubview(airlineLabel)
        
        // Add origin country (only field available from OpenSky)
        let routeLabel = UILabel(frame: CGRect(x: 20, y: 68, width: popup.bounds.width - 40, height: 20))
        routeLabel.text = "Origin: \(flight.originCountry)"
        routeLabel.font = UIFont.systemFont(ofSize: 13)
        routeLabel.textColor = .secondaryLabel
        popup.addSubview(routeLabel)
        
        // Add altitude
        let altitudeText = String(format: "%.0f ft", (flight.baroAltitude ?? 0) * 3.28084)
        let altitudeLabel = UILabel(frame: CGRect(x: 20, y: 92, width: popup.bounds.width - 40, height: 20))
        altitudeLabel.text = "Altitude: \(altitudeText)"
        altitudeLabel.font = UIFont.systemFont(ofSize: 13)
        altitudeLabel.textColor = .secondaryLabel
        popup.addSubview(altitudeLabel)
        
        // Add swipe indicator BELOW altitude row
        if shuffledFlights.count > 1 {
            let swipeIndicator = UILabel(frame: CGRect(x: 20, y: 116, width: popup.bounds.width - 40, height: 14))
            swipeIndicator.text = "← Swipe to browse flights (\(currentShuffleIndex + 1)/\(shuffledFlights.count)) →"
            swipeIndicator.font = UIFont.systemFont(ofSize: 11)
            swipeIndicator.textColor = .tertiaryLabel
            swipeIndicator.textAlignment = .center
            popup.addSubview(swipeIndicator)
        }
        
        // Add close button
        let closeButton = UIButton(frame: CGRect(x: popup.bounds.width - 44, y: 12, width: 32, height: 32))
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.secondaryLabel, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        closeButton.addTarget(self, action: #selector(dismissFlightDetail), for: .touchUpInside)
        popup.addSubview(closeButton)
        
        flightDetailView = popup
        view.addSubview(popup)
        
        // Add compass to popup if in shuffle mode
        if !shuffledFlights.isEmpty, let flightLat = flight.latitude, let flightLon = flight.longitude {
            addPopupCompass(to: popup, flightLat: flightLat, flightLon: flightLon)
        }
        
        // Animate in
        popup.transform = CGAffineTransform(translationX: 0, y: 200)
        popup.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            popup.transform = .identity
            popup.alpha = 1
        }
    }
    
    private func addPopupCompass(to popup: UIView, flightLat: Double, flightLon: Double) {
        // Remove old compass
        popupCompass?.removeFromSuperview()
        
        // Create small compass on right side of popup - match main compass style
        let compassSize: CGFloat = 70
        let compassX = popup.bounds.width - compassSize - 15
        let compassY = 50
        
        let compass = UIView(frame: CGRect(x: compassX, y: CGFloat(compassY), width: compassSize, height: compassSize))
        compass.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        compass.layer.cornerRadius = compassSize / 2
        compass.layer.borderWidth = 2
        compass.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        
        // Add inner cyan ring to match main compass
        let innerRing = UIView(frame: compass.bounds)
        innerRing.backgroundColor = UIColor.clear
        innerRing.layer.cornerRadius = compassSize / 2
        innerRing.layer.borderWidth = 1
        innerRing.layer.borderColor = UIColor.cyan.withAlphaComponent(0.6).cgColor
        compass.addSubview(innerRing)
        
        // Add NSEW labels that will rotate
        let directions = ["N", "E", "S", "W"]
        let angles: [CGFloat] = [0, 90, 180, 270]
        
        for (index, direction) in directions.enumerated() {
            let label = UILabel()
            label.text = direction
            label.textColor = .white
            label.font = UIFont.boldSystemFont(ofSize: 12)
            label.textAlignment = .center
            label.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
            
            let angle = angles[index] * .pi / 180
            let radius: CGFloat = 22
            label.center = CGPoint(
                x: compassSize / 2 + radius * cos(angle),
                y: compassSize / 2 + radius * sin(angle)
            )
            
            compass.addSubview(label)
        }
        
        // Add fixed blue arrow pointing to flight
        let arrowView = UIView(frame: CGRect(x: compassSize / 2 - 8, y: compassSize / 2 - 8, width: 16, height: 16))
        arrowView.backgroundColor = .clear
        
        let arrowLayer = CAShapeLayer()
        let arrowPath = UIBezierPath()
        arrowPath.move(to: CGPoint(x: 8, y: 0))    // Top point
        arrowPath.addLine(to: CGPoint(x: 0, y: 10)) // Left point
        arrowPath.addLine(to: CGPoint(x: 3, y: 10))  // Left notch
        arrowPath.addLine(to: CGPoint(x: 3, y: 16))  // Bottom
        arrowPath.addLine(to: CGPoint(x: 13, y: 16)) // Bottom
        arrowPath.addLine(to: CGPoint(x: 13, y: 10)) // Right notch
        arrowPath.addLine(to: CGPoint(x: 16, y: 10)) // Right point
        arrowPath.close()
        
        arrowLayer.path = arrowPath.cgPath
        arrowLayer.fillColor = UIColor.systemBlue.cgColor
        arrowView.layer.addSublayer(arrowLayer)
        
        compass.addSubview(arrowView)
        compass.tag = 2000 // Tag for popup compass
        popup.addSubview(compass)
        popupCompass = compass
        
        // Start updating compass to point at flight
        updatePopupCompass(flightLat: flightLat, flightLon: flightLon)
    }
    
    private func updatePopupCompass(flightLat: Double, flightLon: Double) {
        guard let compass = popupCompass, let userLoc = currentLocation else { return }
        
        // Calculate bearing from user to flight
        let lat1 = userLoc.coordinate.latitude * .pi / 180
        let lat2 = flightLat * .pi / 180
        let dLon = (flightLon - userLoc.coordinate.longitude) * .pi / 180
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        
        // Get device heading
        guard let frame = sceneView.session.currentFrame else { return }
        let cameraTransform = frame.camera.transform
        let forward = SIMD3<Float>(cameraTransform.columns.2.x, 0, cameraTransform.columns.2.z)
        let deviceHeading = Double(atan2(forward.x, forward.z) * 180 / .pi)
        
        // Relative bearing from device heading to flight
        let relativeBearing = bearing - deviceHeading
        
        // Rotate NSEW labels to compensate for device heading (like main compass)
        let labelContainer = compass.subviews.first { subview in
            if let borderColor = subview.layer.borderColor {
                return UIColor(cgColor: borderColor) == UIColor.cyan.withAlphaComponent(0.6)
            }
            return false
        }
        labelContainer?.transform = CGAffineTransform(rotationAngle: CGFloat(deviceHeading) * .pi / 180)
        
        // Rotate blue arrow to point at flight
        compass.subviews.forEach { subview in
            if subview.frame.size == CGSize(width: 16, height: 16) {
                let rotation = CGFloat(relativeBearing) * .pi / 180
                subview.transform = CGAffineTransform(rotationAngle: rotation)
            }
        }
    }
    
    @objc private func dismissFlightDetail() {
        guard let popup = flightDetailView else { return }
        
        UIView.animate(withDuration: 0.2, animations: {
            popup.transform = CGAffineTransform(translationX: 0, y: 200)
            popup.alpha = 0
        }) { _ in
            popup.removeFromSuperview()
            self.flightDetailView = nil
            self.popupCompass = nil
            self.shuffledFlights = []
            self.currentShuffleIndex = 0
        }
    }
    
    private func updateCompass(for flights: [Flight]) {
        // Ensure compass view exists
        guard let compass = compassView else {
            NSLog("⚠️ Compass view not initialized yet")
            return
        }
        
        // Remove old plane indicators (all subviews except headingIndicator and ringContainer)
        compass.subviews.forEach { subview in
            if subview !== headingIndicator && subview.tag != 999 {
                subview.removeFromSuperview()
            }
        }
        
        // Add plane indicators
        for flight in flights.prefix(10) { // Show first 10 flights
            guard let lat = flight.latitude, let lon = flight.longitude else { continue }
            
            // Use device location if available, otherwise fallback
            let userLat: Double
            let userLon: Double
            
            if let location = currentLocation {
                userLat = location.coordinate.latitude
                userLon = location.coordinate.longitude
            } else {
                userLat = 37.8087
                userLon = -122.4098
            }
            
            // Calculate offset in meters
            let metersPerDegreeLat = 111000.0
            let metersPerDegreeLon = 85000.0
            
            let northMeters = (lat - userLat) * metersPerDegreeLat
            let eastMeters = (lon - userLon) * metersPerDegreeLon
            
            // Calculate bearing (relative to north)
            let bearing = atan2(eastMeters, northMeters) * 180 / .pi
            
            // Create plane indicator
            let indicator = UIView(frame: CGRect(x: 0, y: 0, width: 6, height: 6))
            indicator.backgroundColor = .systemRed
            indicator.layer.cornerRadius = 3
            indicator.tag = 1000 // Tag for plane indicators
            
            let angle = CGFloat(bearing) * .pi / 180
            let radius: CGFloat = 38
            indicator.center = CGPoint(
                x: 60 + radius * sin(angle),
                y: 60 - radius * cos(angle)
            )
            
            compass.addSubview(indicator)
        }
    }
    
    private func setupBackendSubscriptions() {
        NSLog("🔔 Setting up flight service subscriptions...")
        // Subscribe to flight updates
        flightService.$flights
            .sink { [weak self] flights in
                NSLog("🛫 ARView: Received %d flights from backend", flights.count)
                for flight in flights.prefix(3) {
                    NSLog("  ✈️ %@: lat=%.4f, lon=%.4f, alt=%.0f", 
                          flight.callsign, flight.latitude ?? 0, flight.longitude ?? 0, flight.baroAltitude ?? 0)
                }
                self?.currentFlights = flights
                
                // Temporarily disable trajectories - causing too many issues
                // self?.updateFlightTrajectories()
                self?.updateARVisualization()
                self?.updateCompass(for: flights)
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
        NSLog("🚀🚀🚀 ARView: Starting flight data updates...")
        NSLog("📡 Using OpenSky Service with MOCK data")
        
        // Fetch initial flight data
        NSLog("🌐 Calling fetchFlights() for the first time...")
        flightService.fetchFlights()
        
        // Start periodic flight data updates (service handles caching)
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            NSLog("⏰ ARView: Timer fired - fetching flights...")
            self?.flightService.fetchFlights()
        }
        NSLog("✅ Timer scheduled successfully")
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
        print("🎨 ARView: Updating AR visualization for \(currentFlights.count) flights")
        // Update flight positions and trajectories in AR space
        for flight in currentFlights {
            updateFlightPosition(flight)
            updateTrajectoryVisualization(for: flight.id, trajectory: flightTrajectories[flight.id] ?? [])
        }
        print("📍 ARView: Total flight nodes in scene: \(flightNodes.count)")
    }
    
    private func updateFlightPosition(_ flight: Flight) {
        guard let lat = flight.latitude,
              let lon = flight.longitude else { 
            print("⚠️ Flight \(flight.callsign) missing coordinates")
            return 
        }
        
        // Get predicted altitude
        let altitude = altitudeFallback.estimateAltitude(for: flight, with: currentFlights)
        
        // Convert to AR world coordinates
        let worldPosition = convertToARWorldCoordinates(
            latitude: lat,
            longitude: lon,
            altitude: altitude
        )
        
        print("📍 Flight \(flight.callsign): lat=\(lat), lon=\(lon), alt=\(altitude) → AR pos=(\(worldPosition.x), \(worldPosition.y), \(worldPosition.z))")
        
        // Create or update flight node
        let flightNode = getOrCreateFlightNode(for: flight.id)
        flightNode.position = SCNVector3(worldPosition.x, worldPosition.y, worldPosition.z)
        
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
        
        guard trajectory.count >= 2 else { return node }
        
        // Create curved path from trajectory points
        let points = trajectory.map { point in
            convertToARWorldCoordinates(
                latitude: point.latitude,
                longitude: point.longitude,
                altitude: point.altitude
            )
        }
        
        // Create smooth curve using linear interpolation
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]
            
            // Create smooth curve between p1 and p2
            let segments = 20 // Number of segments for smooth curve
            for j in 0..<segments {
                let t = Float(j) / Float(segments)
                
                // Linear interpolation
                let point = p1 + (p2 - p1) * t
                
                let nextT = Float(j + 1) / Float(segments)
                let nextPoint = p1 + (p2 - p1) * nextT
                
                let lineNode = createLineNode(from: point, to: nextPoint)
                node.addChildNode(lineNode)
            }
        }
        
        return node
    }
    
    private func createLineNode(from: SIMD3<Float>, to: SIMD3<Float>) -> SCNNode {
        let lineNode = SCNNode()
        
        // Calculate distance and direction
        let distance = length(to - from)
        
        // Create cylinder geometry for trajectory line
        let cylinder = SCNCylinder(radius: 0.01, height: CGFloat(distance))
        cylinder.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.8)
        cylinder.firstMaterial?.lightingModel = .constant
        
        let geometryNode = SCNNode(geometry: cylinder)
        
        // Position at midpoint
        let midPoint = (from + to) / 2
        geometryNode.position = SCNVector3(midPoint.x, midPoint.y, midPoint.z)
        
        // Calculate direction vector
        let direction = to - from
        
        // Cylinder default is along Y axis, we need to rotate it to align with our direction
        // Calculate rotation axis (cross product of Y axis with our direction)
        let yAxis = SIMD3<Float>(0, 1, 0)
        let normalizedDirection = normalize(direction)
        let rotationAxis = cross(yAxis, normalizedDirection)
        
        // Calculate rotation angle
        let angle = acos(dot(yAxis, normalizedDirection))
        
        // Apply rotation
        if length(rotationAxis) > 0.001 { // Avoid division by zero
            geometryNode.rotation = SCNVector4(
                rotationAxis.x,
                rotationAxis.y,
                rotationAxis.z,
                angle
            )
        }
        
        lineNode.addChildNode(geometryNode)
        return lineNode
    }
    
    // MARK: - Coordinate Conversion
    
    private func convertToARWorldCoordinates(latitude: Double, longitude: Double, altitude: Double) -> SIMD3<Float> {
        // Verify AR session is running
        guard sceneView.session.currentFrame != nil else {
            return SIMD3<Float>(0, 0, 0)
        }
        
        // Use device's actual location if available, otherwise fallback to Pier 39
        let userLat: Double
        let userLon: Double
        let userAlt: Double
        
        if let location = currentLocation {
            userLat = location.coordinate.latitude
            userLon = location.coordinate.longitude
            userAlt = location.altitude
            NSLog("📍 Using device location: lat=\(userLat), lon=\(userLon)")
        } else {
            // Fallback to Pier 39
            userLat = 37.8087
            userLon = -122.4098
            userAlt = 10.0
            NSLog("📍 Using fallback location (Pier 39)")
        }
        
        // Calculate offset from user position in meters
        let latDiff = latitude - userLat
        let lonDiff = longitude - userLon
        let altDiff = altitude - userAlt
        
        // Convert degrees to meters (rough approximation)
        // At SF latitude: 1° lat ≈ 111km, 1° lon ≈ 85km
        let metersPerDegreeLat = 111000.0
        let metersPerDegreeLon = 85000.0
        
        let northMeters = latDiff * metersPerDegreeLat
        let eastMeters = lonDiff * metersPerDegreeLon
        
        // Convert to AR coordinates (scale down for AR visualization)
        // Use 1:1000 scale so 1km = 1 meter in AR
        let x = Float(eastMeters / 1000.0)     // East/West
        let y = Float(altDiff / 1000.0)        // Altitude (meters to AR units, 1:1000 scale)
        let z = Float(-northMeters / 1000.0)   // North/South (negative Z is forward)
        
        NSLog("🔄 Coord conversion: latDiff=\(latDiff)° -> northMeters=\(northMeters)m -> z=\(z)")
        
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
        
        // Create aircraft geometry - make it clearly visible!
        let aircraftGeometry = SCNBox(width: 0.08, height: 0.03, length: 0.15, chamferRadius: 0.01)
        aircraftGeometry.firstMaterial?.diffuse.contents = UIColor.systemRed
        aircraftGeometry.firstMaterial?.emission.contents = UIColor.red
        aircraftGeometry.firstMaterial?.lightingModel = .constant // Always bright
        
        let geometryNode = SCNNode(geometry: aircraftGeometry)
        node.addChildNode(geometryNode)
        
        // Add a large invisible sphere for easy tapping (much larger than the visible plane)
        let tapGeometry = SCNSphere(radius: 0.3)
        tapGeometry.firstMaterial?.diffuse.contents = UIColor.clear
        let tapNode = SCNNode(geometry: tapGeometry)
        tapNode.name = "tapTarget"
        node.addChildNode(tapNode)
        
        // Add a target ring around the plane - will billboard to face camera
        let ringGeometry = SCNTorus(ringRadius: 0.12, pipeRadius: 0.005)
        ringGeometry.firstMaterial?.diffuse.contents = UIColor.systemRed.withAlphaComponent(0.6)
        ringGeometry.firstMaterial?.lightingModel = .constant
        
        let ringNode = SCNNode(geometry: ringGeometry)
        ringNode.name = "targetRing" // Tag for billboard behavior
        
        // Add billboard constraint to always face the camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.X, .Y, .Z] // Free on all axes
        ringNode.constraints = [billboardConstraint]
        
        node.addChildNode(ringNode)
        
        return node
    }
    
    private func addFlightInfoToNode(_ node: SCNNode, flight: Flight) {
        // Remove old text if exists
        node.childNodes.filter { $0.geometry is SCNText }.forEach { $0.removeFromParentNode() }
        
        // Calculate distance from user to plane
        var distanceKm: Double = 0
        if let userLoc = currentLocation, let planeLat = flight.latitude, let planeLon = flight.longitude {
            let distance = userLoc.distance(from: CLLocation(latitude: planeLat, longitude: planeLon))
            distanceKm = distance / 1000.0
        }
        
        // Build info string with optional data
        var infoParts: [String] = [flight.callsign]
        
        // Add distance if available
        if distanceKm > 0 {
            if distanceKm < 1 {
                infoParts.append(String(format: "%.1f km", distanceKm))
            } else {
                infoParts.append(String(format: "%.0f km", distanceKm))
            }
        }
        
        // Add speed if available
        if let velocity = flight.velocity {
            infoParts.append(String(format: "%.0f kts", velocity))
        }
        
        // Add altitude if available
        if let altitude = flight.baroAltitude {
            infoParts.append(String(format: "%.0f ft", altitude * 3.28084))
        }
        
        let infoString = infoParts.joined(separator: "\n")
        
        let textGeometry = SCNText(string: infoString, extrusionDepth: 0.01)
        textGeometry.font = UIFont.boldSystemFont(ofSize: 8)
        textGeometry.flatness = 0.1
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        textGeometry.firstMaterial?.lightingModel = .constant
        
        // Center the text horizontally
        let (min, max) = textGeometry.boundingBox
        let dx = (max.x - min.x) / 2
        let dy = (max.y - min.y) / 2
        textGeometry.containerFrame = CGRect(x: CGFloat(-dx), y: CGFloat(-dy), width: CGFloat(max.x - min.x), height: CGFloat(max.y - min.y))
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.name = "flightInfo" // Tag for billboard behavior
        textNode.position = SCNVector3(0, 0.3, 0)  // Above the aircraft
        textNode.scale = SCNVector3(0.005, 0.005, 0.005)
        
        // Add billboard constraint - completely free rotation to always face camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.X, .Y, .Z] // Free on all axes for true billboard
        textNode.constraints = [billboardConstraint]
        
        node.addChildNode(textNode)
        
        // Add direction arrow if heading available
        if let heading = flight.trueTrack {
            addDirectionArrow(to: node, heading: heading)
        }
    }
    
    private func addDirectionArrow(to node: SCNNode, heading: Double) {
        // Create a small arrow showing flight direction
        let arrowGeometry = SCNBox(width: 0.02, height: 0.001, length: 0.06, chamferRadius: 0.001)
        arrowGeometry.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.7)
        arrowGeometry.firstMaterial?.lightingModel = .constant
        
        let arrowNode = SCNNode(geometry: arrowGeometry)
        arrowNode.position = SCNVector3(0, 0.12, 0) // Below the plane
        
        // Rotate arrow to match heading (heading is in degrees, 0 = north)
        let headingRadians = Float(heading) * .pi / 180.0
        arrowNode.rotation = SCNVector4(0, 1, 0, headingRadians)
        
        node.addChildNode(arrowNode)
    }
}
