//
//  MainViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//


import UIKit

class MainViewController: UIViewController {

    // Segment Control, Container View
    private let modeSegment: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Record", "Video"])
        sc.selectedSegmentIndex = 0
        sc.backgroundColor = .gray
        return sc
    }()
    
    // Cái hộp rỗng để chứa màn hình con
    private let containerView = UIView()
    
    // Hai màn hình con
    private lazy var recorderVC: RecorderViewController = {
        let storyboard = UIStoryboard(name: "Recorder", bundle: nil)
        return storyboard.instantiateInitialViewController() as! RecorderViewController
    }()
    
    private lazy var cameraVC: CameraViewController = {
        return CameraViewController()
    }()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        
        // Hiện màn hình Record trước
        add(childVC: recorderVC)
    }
    
    private func setupUI() {
        view.addSubview(containerView)
        view.addSubview(modeSegment)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        modeSegment.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            
            modeSegment.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -200),
            modeSegment.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeSegment.widthAnchor.constraint(equalToConstant: 200),
            modeSegment.heightAnchor.constraint(equalToConstant: 30),
            
            // Container View chiếm hết phần còn lại
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Bắt sự kiện bấm nút
        modeSegment.addTarget(self, action: #selector(didChangeMode), for: .valueChanged)
    }
    
    @objc private func didChangeMode(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            // Chuyển sang Audio
            remove(childVC: cameraVC)
            add(childVC: recorderVC)
        } else {
            // Chuyển sang Video
            remove(childVC: recorderVC)
            add(childVC: cameraVC)
        }
    }
    
    // MARK: - Logic thay thế màn hình con
    
    private func add(childVC: UIViewController) {
        // Thêm vào quan hệ cha-con
        addChild(childVC)
        
        // Thêm view của con vào container
        containerView.addSubview(childVC.view)
        
        // Neo view con cho vừa container
        childVC.view.frame = containerView.bounds
        childVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Báo xong
        childVC.didMove(toParent: self)
    }
    
    private func remove(childVC: UIViewController) {
        // Báo chuẩn bị rời đi
        childVC.willMove(toParent: nil)
        
        // Gỡ view ra
        childVC.view.removeFromSuperview()
        
        // Gỡ quan hệ cha-con
        childVC.removeFromParent()
    }
}
