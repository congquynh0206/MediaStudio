//
//  VisualizerView.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//


import UIKit

class VisualizerView: UIView {
    
    // Config
    private let barCount = 20
    private let spacing: CGFloat = 4.0
    
    // State
    private var barLayers: [CALayer] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        self.backgroundColor = .clear
        self.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        barLayers.removeAll()
        
        for _ in 0..<barCount {
            let layer = CALayer()
            layer.backgroundColor = UIColor.systemRed.cgColor
            layer.cornerRadius = 2
            self.layer.addSublayer(layer)
            barLayers.append(layer)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Tính toán kích thước cột
        //Chỉ set vị trí X ban đầu. Chiều cao sẽ do updateWaveform quyết định.
        
        let totalSpacing = CGFloat(barCount - 1) * spacing
        let barWidth = (bounds.width - totalSpacing) / CGFloat(barCount)
        let midY = bounds.height / 2
        
        for (index, layer) in barLayers.enumerated() {
            let x = CGFloat(index) * (barWidth + spacing)
            
            // Nếu layer chưa có frame, set chiều cao mặc định nhỏ
            if layer.frame == .zero {
                 layer.frame = CGRect(x: x, y: midY - 1, width: barWidth, height: 2)
            } else {
                // Nếu đã có frame, chỉ update lại width và x (phòng khi xoay màn hình), giữ nguyên height đang nhảy
                let currentHeight = layer.frame.height
                layer.frame = CGRect(x: x, y: midY - currentHeight/2, width: barWidth, height: currentHeight)
            }
        }
    }
    
    func updateWaveform(value: Float) {
        guard bounds.height > 0 else { return }
        
        let normalized = max(0.05, CGFloat(value + 60) / 60) // Min 0.05 để luôn thấy vạch mờ
        
        for layer in barLayers {
            let height = min(normalized * bounds.height, bounds.height)
            
            let midY = bounds.height / 2
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = CGRect(
                x: layer.frame.origin.x,
                y: midY - height / 2,
                width: layer.frame.width,
                height: height
            )
            CATransaction.commit()
        }
    }
}
