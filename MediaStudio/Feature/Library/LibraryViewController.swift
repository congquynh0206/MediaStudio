//
//  LibraryViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 23/1/26.
//


import UIKit

class LibraryViewController: UIViewController, UISearchResultsUpdating {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var trashButton: UIButton!

        
    
    private let searchController = UISearchController(searchResultsController: nil)
    
    
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
        let selectedItem = viewModel.items[indexPath.row]
//        viewModel.playItem(at: indexPath.row)
        let storyboard = UIStoryboard(name: "Library", bundle: nil)
        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.itemToPlay = selectedItem
            
            if let nav = navigationController {
                nav.pushViewController(playerVC, animated: true)
            } else {
                present(playerVC, animated: true)
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
    
    // Popup nhập tên
    private func showRenameAlert(at indexPath: IndexPath) {
        let alert = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "Enter a new name..."
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
}
