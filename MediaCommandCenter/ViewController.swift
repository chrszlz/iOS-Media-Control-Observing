//
//  ViewController.swift
//  MediaCommandCenter
//
//  Created by Chris Zelazo on 7/17/19.
//  Copyright © 2019 Chris Zelazo. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 36, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = "-"
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        view.addSubview(valueLabel)
        valueLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        valueLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        /// Begin Media Command observing
        MediaCommandCenter.addObserver(self)
        MediaCommandCenter.observedCommands = [.volume, .togglePlayPause]
        ///
    }
    
    deinit {
        /// Remove observers
        MediaCommandCenter.removeObserver(self)
        ///
    }
    
}

extension ViewController: MediaCommandObserver {

    func mediaCommandCenterHandleVolumeChanged(_ volume: Double) {
        // Format volume value to 2 decimal places - [0.00, 1.00]
        valueLabel.text = String(format: "%.2f", volume)
    }
    
    func mediaCommandCenterHandleTogglePlayPause() {
        UIView.animate(withDuration: 0.5) {
            self.valueLabel.transform = self.valueLabel.transform.rotated(by: .pi)
        }
    }

}

