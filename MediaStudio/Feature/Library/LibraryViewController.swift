//
//  LibraryViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//


import UIKit

class LibraryViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    // Kéo 1 cái Label nhỏ hiển thị trạng thái "Đang phát..." (Optional)
    
    private let viewModel = LibraryViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Danh Sách Ghi Âm"
        setupTableView()
        bindViewModel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadData() // Load lại mỗi khi vào màn hình
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 80
    }
    
    private func bindViewModel() {
        viewModel.onDataLoaded = { [weak self] in
            self?.tableView.reloadData()
        }
        
        viewModel.onPlaybackStatusChanged = { isPlaying in
            // Logic UI khi đang phát (ví dụ hiện Toast hoặc đổi màu cell)
            print(isPlaying ? "Đang phát nhạc..." : "Đã dừng.")
        }
    }
}

// MARK: - TableView
extension LibraryViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MediaCell", for: indexPath) as? MediaCell else {
            return UITableViewCell()
        }
        cell.configure(with: viewModel.items[indexPath.row])
        return cell
    }
    
    // Bấm vào dòng để phát
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.playItem(at: indexPath.row)
    }
    
    // Vuốt để xóa
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            viewModel.deleteItem(at: indexPath.row)
        }
    }
}