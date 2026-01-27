//
//  TrashViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 27/1/26.
//


import UIKit

class TrashViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    private let viewModel = TrashViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Thùng Rác"
        setupTableView()
        setupHeaderView()
        
        viewModel.onDataLoaded = { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadTrashItems()
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func setupHeaderView() {
        // Tạo view chứa
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 40))
        
        // Tạo Label
        let label = UILabel()
        label.text = "Các file trong thùng rác sẽ tự động bị xóa sau 30 ngày"
        label.textColor = .secondaryLabel // Màu chữ xám
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textAlignment = .center
        label.frame = headerView.bounds
        
        // Gắn vào TableView
        headerView.addSubview(label)
        tableView.tableHeaderView = headerView
    }

    // MARK: - DataSource
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
    
    // MARK: - Swipe Actions
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        // Nút khôi phục
        let restoreAction = UIContextualAction(style: .normal, title: "Khôi phục") { [weak self] _, _, completion in
            self?.viewModel.restoreItem(at: indexPath.row)
            completion(true)
        }
        restoreAction.backgroundColor = .systemGreen
        restoreAction.image = UIImage(systemName: "arrow.uturn.backward")
        
        // Nút xoá vĩnh viễn
        let deleteAction = UIContextualAction(style: .destructive, title: "Xoá hẳn") { [weak self] _, _, completion in
            guard let self = self else { return }
            
            // Hiện Alert xác nhận
            let alert = UIAlertController(
                title: "Xóa vĩnh viễn?",
                message: "Bạn sẽ không thể khôi phục file ghi âm này. Bạn có chắc không?",
                preferredStyle: .alert
            )
            
            // Nút Hủy
            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                completion(false) // Đóng swipe
            })
            
            // Nút Xóa (Màu đỏ)
            alert.addAction(UIAlertAction(title: "Xóa", style: .destructive) { _ in
                self.viewModel.deletePermanently(at: indexPath.row)
                completion(true)
            })
            
            self.present(alert, animated: true)
        }
        deleteAction.image = UIImage(systemName: "trash.slash")
        
        return UISwipeActionsConfiguration(actions: [deleteAction, restoreAction])
    }
}
