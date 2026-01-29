//
//  TranscriptViewController.swift
//  MediaStudio
//
//  Created by Trangptt on 29/1/26.
//


import UIKit
import Speech

class TranscriptViewController: UIViewController {

    private let textView = UITextView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let searchBar = UISearchBar()
    
    // Data
    var audioURL: URL?
    private var fullText: String = "" // Lưu văn bản gốc để search
    
    var selectedLocale: Locale = Locale(identifier: "vi-VN")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Gỡ băng (Transcript)"
        
        setupUI()
        setupSearchBar()
        
        // Dịch ngay khi mở màn hình
        if let url = audioURL {
            transcribeAudio(url: url)
        }
    }
    
    private func setupUI() {
        // Search Bar
        searchBar.placeholder = "Search in transcript"
        searchBar.delegate = self
        view.addSubview(searchBar)
        
        // Text View
        textView.font = .systemFont(ofSize: 18)
        textView.isEditable = false // read only
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 15, bottom: 20, right: 15)
        view.addSubview(textView)
        
        // Loading
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        
        // Layout
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Search Bar
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Text View
            textView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Loading
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupSearchBar() {
        // Thêm nút "Done" trên bàn phím
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneBtn = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        toolbar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), doneBtn]
        searchBar.inputAccessoryView = toolbar
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Logic Dịch (Speech to Text)
    private func transcribeAudio(url: URL) {
        loadingIndicator.startAnimating()
        textView.text = "Analyzing voice..."
        
        // Xin quyền trước
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.performTranscription(url: url)
                } else {
                    self.loadingIndicator.stopAnimating()
                    self.textView.text = "Lỗi: You haven't granted Speech Recognition permission in Settings.."
                }
            }
        }
    }
    
    private func performTranscription(url: URL) {
        guard let recognizer = SFSpeechRecognizer(locale: selectedLocale) else { return }
        
        if !recognizer.isAvailable {
            self.textView.text = "The service is not available at this time."
            self.loadingIndicator.stopAnimating()
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false // Chỉ lấy kết quả cuối
        
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.loadingIndicator.stopAnimating()
                self.textView.text = "Cannot be translated: \(error.localizedDescription)"
            } else if let result = result, result.isFinal {
                self.loadingIndicator.stopAnimating()
                
                // Thành công
                self.fullText = result.bestTranscription.formattedString
                self.textView.text = self.fullText
            }
        }
    }
}

// MARK: - Search, Highlight
extension TranscriptViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Nếu xóa trắng thì hiện lại text gốc
        guard !searchText.isEmpty else {
            textView.attributedText = NSAttributedString(string: fullText, attributes: [.font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.label])
            return
        }
        
        // Tạo chuỗi văn bản có định dạng
        let attributedString = NSMutableAttributedString(string: fullText, attributes: [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.label
        ])
        
        // Tìm và tô màu nền vàng
        let pattern = searchText.lowercased()
        let baseString = fullText.lowercased()
        
        var searchRange = baseString.startIndex..<baseString.endIndex
        
        while let range = baseString.range(of: pattern, options: .caseInsensitive, range: searchRange) {
            let nsRange = NSRange(range, in: baseString)
            
            attributedString.addAttribute(.backgroundColor, value: UIColor.systemYellow, range: nsRange)
            attributedString.addAttribute(.foregroundColor, value: UIColor.black, range: nsRange)
            
            // Dịch chuyển vùng tìm kiếm tiếp theo
            searchRange = range.upperBound..<baseString.endIndex
        }
        
        textView.attributedText = attributedString
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder() // Ẩn bàn phím khi bấm Enter
    }
}
