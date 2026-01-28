//
//  LibraryViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//


import UIKit
import AVFoundation

class LibraryViewController: UIViewController, UISearchResultsUpdating {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var trashButton: UIButton!

    private let searchController = UISearchController(searchResultsController: nil)
    
    
    private let bottomToolbar = UIToolbar()
   
    // Selected Lít
    private var selectedItemsOrdered: [MediaItem] = []
    
    
    private let viewModel = LibraryViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        title = "Record List"
        setupTableView()
        bindViewModel()
        setupSearchController()
        setupSortButton()
        setupTrashButton()
        setupSelectModeUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadData()
    }
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false // Không làm tối màn hình
        searchController.searchBar.placeholder = "Search"
        
        
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false // Luôn hiện
    }
    
    // Nút sắp xếp
    private func setupSortButton() {
        let sortMenu = UIMenu(title: "Sort by", children: [
            UIAction(title: "Newest", image: UIImage(systemName: "arrow.down.circle"), handler: { _ in
                self.viewModel.sort(by: .newest)
            }),
            UIAction(title: "Oldest", image: UIImage(systemName: "arrow.up.circle"), handler: { _ in
                self.viewModel.sort(by: .oldest)
            }),
            UIAction(title: "Name A-Z", image: UIImage(systemName: "textformat"), handler: { _ in
                self.viewModel.sort(by: .nameAZ)
            }),
            UIAction(title: "Name Z-A", image: UIImage(systemName: "textformat"), handler: { _ in
                self.viewModel.sort(by: .nameZA)
            })
        ])
        
        let sortButton = UIBarButtonItem(title: nil, image: UIImage(systemName: "line.3.horizontal.decrease.circle"), primaryAction: nil, menu: sortMenu)
        navigationItem.rightBarButtonItem = sortButton
    }
    
    
    private func setupSelectModeUI() {
        // Nút Select góc trái
        let selectButton = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(didTapSelectButton))
        navigationItem.leftBarButtonItem = selectButton
        
        // Cho phép chọn nhiều dòng
        tableView.allowsMultipleSelectionDuringEditing = true
        
        // Toolbar
        view.addSubview(bottomToolbar)
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Tạo các nút trong Toolbar
        let deleteBtn = UIBarButtonItem(title: "Delete All", style: .plain, target: self, action: #selector(didTapDeleteSelected))
        deleteBtn.tintColor = .systemRed
        
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let mergeBtn = UIBarButtonItem(title: "Merge", style: .plain, target: self, action: #selector(didTapMergeSelected))
        
        bottomToolbar.items = [deleteBtn, spacer, mergeBtn]
        bottomToolbar.isHidden = true // Mặc định ẩn
    }
    
    @objc private func didTapSelectButton() {
        let isEditing = !tableView.isEditing
        tableView.setEditing(isEditing, animated: true)
        
        // Đổi tên
        navigationItem.leftBarButtonItem?.title = isEditing ? "Cancel" : "Select"
        navigationItem.leftBarButtonItem?.style = isEditing ? .done : .plain
        
        // Hiện/Ẩn Toolbar
        bottomToolbar.isHidden = !isEditing
        
        // Reset danh sách chọn
        selectedItemsOrdered.removeAll()
        
        // Ẩn các nút khác
        navigationItem.rightBarButtonItem?.isEnabled = !isEditing // Nút sort
    }
    
    // Button thùng rác
    private func setupTrashButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold, scale: .large)
        
        if #available(iOS 15.0, *) {
            trashButton.configuration?.preferredSymbolConfigurationForImage = config
        } else {
            trashButton.setPreferredSymbolConfiguration(config, forImageIn: .normal)
        }
        // Hiệu ứng bóng đổ (Shadow) cho nổi
        trashButton.layer.shadowColor = UIColor.black.cgColor
        trashButton.layer.shadowOpacity = 0.3
        trashButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        trashButton.layer.shadowRadius = 5
    }
    
    // MARK: - Delegate
    // Hàm chạy mỗi khi gõ 1 chữ
    func updateSearchResults(for searchController: UISearchController) {
        guard let text = searchController.searchBar.text else { return }
        
        viewModel.search(query: text)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsVerticalScrollIndicator = false
        tableView.showsHorizontalScrollIndicator = false
    }
    
    private func bindViewModel() {
        viewModel.onDataLoaded = { [weak self] in
            self?.tableView.reloadData()
        }
        
        viewModel.onPlaybackStatusChanged = { isPlaying in
            print(isPlaying ? "Đang phát nhạc" : "Đã dừng.")
        }
    }
    // Popup nhập tên
    private func showRenameAlert(at indexPath: IndexPath) {
        let alert = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Enter a new name"
            // Điền sẵn tên cũ
            tf.text = self.viewModel.items[indexPath.row].name
        }
        
        let okAction = UIAlertAction(title: "Save", style: .default) { _ in
            if let newName = alert.textFields?.first?.text, !newName.isEmpty {
                self.viewModel.renameItem(index: indexPath.row, newName: newName)
            }
        }
        alert.addAction(okAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // Chia sẻ file
    private func shareItem(at indexPath: IndexPath) {
        let item = viewModel.items[indexPath.row]
        guard let url = item.fullFileURL else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    // Delete all
    @objc private func didTapDeleteSelected() {
        guard !selectedItemsOrdered.isEmpty else { return }
        
        let alert = UIAlertController(title: "Delete", message: "Are you sure you want to delete \(self.selectedItemsOrdered.count) files?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
            
            // Xóa trong ViewModel/Database
            self.viewModel.deleteAllItem(list: self.selectedItemsOrdered)
            
            // Xong thì thoát chế độ Edit
            self.didTapSelectButton()
        }))
        present(alert, animated: true)
    }
    
    // Merge
    @objc private func didTapMergeSelected() {
        guard selectedItemsOrdered.count >= 2 else {
            let alert = UIAlertController(title: "Warning", message: "Please select at least 2 files to merge.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let alert = UIAlertController(title: "Merge Files", message: "The pairing order is the order in which you select your items. \nEnter new file name", preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.placeholder = "File name"
            tf.text = "Merged_Audio"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            guard let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            self.performMerge(outputName: name)
        }))
        
        present(alert, animated: true)
    }
    
    // Hàm xử lý Merge
    private func performMerge(outputName: String) {
        let loading = UIAlertController(title: "Processing...", message: nil, preferredStyle: .alert)
        present(loading, animated: true)
        viewModel.mergeItems(selectedItems: selectedItemsOrdered, outputName: outputName) { [weak self] success, errorMsg in
            
            // Update UI
            loading.dismiss(animated: true)
            
            if success {
                self?.didTapSelectButton() // Thoát chế độ chọn
                // Báo thành công
                let successAlert = UIAlertController(title: "Successfully", message: "The files have been merged.!", preferredStyle: .alert)
                successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(successAlert, animated: true)
                
            } else {
                print("Lỗi: \(errorMsg ?? "")")
            }
        }
    }
}

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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = viewModel.items[indexPath.row]
        if tableView.isEditing {
            selectedItemsOrdered.append(item)
        } else {
            let storyboard = UIStoryboard(name: "Library", bundle: nil)
            if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
                playerVC.itemToPlay = item
                
                if let nav = navigationController {
                    nav.pushViewController(playerVC, animated: true)
                } else {
                    present(playerVC, animated: true)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            // Nếu bỏ chọn -> Xóa khỏi danh sách theo dõi
            let item = viewModel.items[indexPath.row]
            if let index = selectedItemsOrdered.firstIndex(where: { $0.id == item.id }) {
                selectedItemsOrdered.remove(at: index)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        // Nút xoá
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.viewModel.deleteItem(at: indexPath.row)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        // Nút đổi tên
        let renameAction = UIContextualAction(style: .normal, title: "Rename") { [weak self] _, _, completion in
            self?.showRenameAlert(at: indexPath)
            completion(true)
        }
        renameAction.backgroundColor = .systemBlue
        renameAction.image = UIImage(systemName: "pencil")
        
        // Nút share
        let shareAction = UIContextualAction(style: .normal, title: "Share") { [weak self] _, _, completion in
            self?.shareItem(at: indexPath)
            completion(true)
        }
        shareAction.backgroundColor = .systemGreen
        shareAction.image = UIImage(systemName: "square.and.arrow.up")
        
        return UISwipeActionsConfiguration(actions: [deleteAction, renameAction, shareAction])
    }
}
