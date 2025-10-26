import UIKit
import Combine

class LoadingViewController: UIViewController {
    
    private let flightService = OpenSkyService()
    private var cancellables = Set<AnyCancellable>()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 36, weight: .bold)
        label.textColor = .black
        label.numberOfLines = 0
        label.text = "Connecting to backend..."
        return label
    }()
    
    private let detailLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        label.textColor = .darkGray
        label.numberOfLines = 0
        label.text = "OpenSky Network API"
        return label
    }()
    
    private var hasReceivedData = false
    private var transitionTimer: Timer?
    private var timeoutTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // Setup UI
        setupUI()
        
        // Subscribe to backend updates
        setupBackendSubscriptions()
        
        // Fetch initial data
        NSLog("🔵 LoadingViewController: Fetching initial flight data...")
        flightService.fetchFlights()
        
        // Set timeout to transition anyway after 10 seconds
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            NSLog("⏰ LoadingViewController: Timeout reached - transitioning to AR anyway")
            self?.transitionToARView()
        }
    }
    
    private func setupUI() {
        // Add status label
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Add detail label
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(detailLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            detailLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detailLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            detailLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            detailLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
    
    private func setupBackendSubscriptions() {
        // Subscribe to flight updates
        flightService.$flights
            .sink { [weak self] flights in
                guard let self = self else { return }
                
                if flights.isEmpty {
                    NSLog("📭 LoadingViewController: Received empty flights array")
                    return
                }
                
                NSLog("✅ LoadingViewController: Received \(flights.count) flights!")
                self.hasReceivedData = true
                
                DispatchQueue.main.async {
                    self.statusLabel.text = "Found \(flights.count) flights"
                    self.detailLabel.text = "in SF Bay Area"
                    
                    // Schedule transition to AR view after 3 seconds
                    self.scheduleTransitionToAR()
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to error messages
        flightService.$errorMessage
            .sink { [weak self] errorMessage in
                guard let self = self, let error = errorMessage else { return }
                
                NSLog("❌ LoadingViewController: Error - \(error)")
                
                DispatchQueue.main.async {
                    self.statusLabel.text = "Connection Error"
                    self.detailLabel.text = error
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to loading state
        flightService.$isLoading
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                
                if isLoading && !self.hasReceivedData {
                    DispatchQueue.main.async {
                        self.statusLabel.text = "Connecting..."
                        self.detailLabel.text = "Fetching flight data"
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func scheduleTransitionToAR() {
        // Cancel any existing timer
        transitionTimer?.invalidate()
        
        // Schedule transition after 3 seconds
        transitionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.transitionToARView()
        }
        
        NSLog("⏰ LoadingViewController: Scheduled transition to AR view in 3 seconds")
    }
    
    private func transitionToARView() {
        // Cancel timers
        transitionTimer?.invalidate()
        timeoutTimer?.invalidate()
        
        NSLog("🚀 LoadingViewController: Transitioning to AR view...")
        
        let arView = ARView()
        arView.modalPresentationStyle = .fullScreen
        arView.modalTransitionStyle = .crossDissolve
        
        present(arView, animated: true) {
            NSLog("✅ LoadingViewController: AR view presented")
        }
    }
    
    deinit {
        transitionTimer?.invalidate()
        timeoutTimer?.invalidate()
    }
}

