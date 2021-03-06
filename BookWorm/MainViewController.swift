//
//  MainViewController.swift
//  BookWorm
//
//  The View Controller where Users browse for Books
//  to purchase. The users are seperated based on college
//
//  Created by Hegde, Vikram on 6/30/16.
//  Copyright © 2016 Hegde, Vikram. All rights reserved.
//

import UIKit
import Firebase

class MainViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    @IBOutlet weak var collegeNameLabel: UILabel!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var divider: UISegmentedControl!
    
    // Variables
    let ref = FIRDatabase.database().reference()
    var school : String = ""
    var noEntries = false
    var books : [Book] = []
    var filteredBooks : [Book] = []
    var inSearchMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.delegate = self
        
        // Parse the school out of the email
        let email: String! = FIRAuth.auth()?.currentUser?.email!
        school = email!.substring(with: Range(email.index(email!.characters.index(of: "@")!, offsetBy: 1) ..< email!.characters.index(of: ".")!))
        collegeNameLabel.text = school.capitalized
        
        addBooksToArray()
    }
    
    // Add the correct books based on the state of the divider
    @IBAction func dividerChanged(_ sender: AnyObject) {
        self.addBooksToArray()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if noEntries {
            return 1
        }
        if inSearchMode{
            return filteredBooks.count // filtered on search and divider
        }
        return books.count
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar.text == nil || searchBar.text == "" {
            inSearchMode = false
            searchBar.resignFirstResponder()
            tableView.reloadData()
        }
        else{
            // Narrow the list to search filling books
            inSearchMode = true
            let lower = searchBar.text?.lowercased()
            filteredBooks = books.filter({$0.title.lowercased().range(of: lower!) != nil || $0.author.lowercased().range(of: lower!) != nil || $0.isbn.lowercased().range(of: lower!) != nil || $0.edition.lowercased().range(of: lower!) != nil})
            tableView.reloadData()
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! BookTableViewCell
        cell.backgroundColor  = UIColor.init(white: 255, alpha: 0)
        if(self.noEntries){
            cell.titleLabel.alpha = 0
            cell.coverImage.alpha = 0
            cell.editionLabel.alpha = 0
            cell.authorsLabel.alpha = 0
            cell.noBookLabel.alpha = 1
            cell.book = nil
        }else{
            cell.titleLabel.alpha = 1
            cell.coverImage.alpha = 1
            cell.editionLabel.alpha = 1
            cell.authorsLabel.alpha = 1
            cell.noBookLabel.alpha = 0
            
            cell.coverImage.image = UIImage(named: "loadingCover")//loading photo when you have MARKERMARKER
            let book: Book!
            if inSearchMode{
                book = filteredBooks[indexPath.row]
            }else{
                book = books[indexPath.row]
            }
            
            let storageRef = FIRStorage.storage().reference(forURL: "gs://bookworm-9f703.appspot.com").child("\(book.isbn)-\(book.uid).png")
            storageRef.data(withMaxSize: 5000*5000, completion: { (data, error) in
                if error == nil {
                    cell.coverImage.image = UIImage(data: data!)
                }else{
                    //print(error!.localizedDescription) // just keeps printing that no photo exists
                    cell.coverImage.image = UIImage(named: "noPhotoSelected")
                }
            })
            cell.titleLabel.text = book.title
            cell.authorsLabel.text = book.author
            cell.editionLabel.text = book.edition
            cell.book = self.books[indexPath.row]
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if noEntries {
            return
        }
        performSegue(withIdentifier: "bookSelected", sender: indexPath.row)
    }
    
    func addBooksToArray(){
        // depending on the divider, filter the books.
        // MARK: Firebase loading
        if self.divider.selectedSegmentIndex == 0{
            self.ref.child(self.school).child("selling").observeSingleEvent(of: .value, with: {    (snapshot) in
                self.books.removeAll()
                if let booksJSON = snapshot.value as? NSArray{
                    self.noEntries = false
                    var index = 0
                    for bookJSON in booksJSON as! [[String: AnyObject]]{
                        let tempAuthor = bookJSON["authors"] as! String
                        let tempTitle = bookJSON["title"] as! String
                        let tempEdition = bookJSON["edition"] as! String
                        let tempPrice = bookJSON["price"] as! String
                        let tempISBN = bookJSON["isbn"] as! String
                        let tempUID = bookJSON["uid"] as! String
                        let isDeleted = bookJSON["isDeleted"] as! Bool
                        if !isDeleted {
                            self.books.append(Book(isbn: tempISBN, title: tempTitle, author: tempAuthor, edition: tempEdition, price: tempPrice, uid: tempUID, index: index))
                        }
                        index += 1;
                    }
                }else{
                    self.noEntries = true
                }
                DispatchQueue.main.async(execute: { () -> Void in
                    self.tableView.reloadData()
                })
            }) { (error) in
                print(error.localizedDescription)
            }
        }else if self.divider.selectedSegmentIndex == 1{
            self.books.removeAll()
            self.ref.child(self.school).child("buying").observeSingleEvent(of: .value, with: {    (snapshot) in
                if let booksJSON = snapshot.value as? NSArray{
                    self.noEntries = false
                    var index = 0
                    for bookJSON in booksJSON as! [[String: AnyObject]]{
                        let tempAuthor = bookJSON["authors"] as! String
                        let tempTitle = bookJSON["title"] as! String
                        let tempEdition = bookJSON["edition"] as! String
                        let tempPrice = bookJSON["price"] as! String
                        let tempISBN = bookJSON["isbn"] as! String
                        let tempUID = bookJSON["uid"] as! String
                        let isDeleted = bookJSON["isDeleted"] as! Bool
                        if !isDeleted {
                            self.books.append(Book(isbn: tempISBN, title: tempTitle, author: tempAuthor, edition: tempEdition, price: tempPrice, uid: tempUID, index: index))
                        }
                    }
                    index += 1
                }else{
                    self.noEntries = true
                }
                DispatchQueue.main.async(execute: { () -> Void in
                    self.tableView.reloadData()
                })
            }) { (error) in
                print(error.localizedDescription)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let bookVC = segue.destination as? BookViewController {
            bookVC.myBook = books[sender as! Int]
            if divider.selectedSegmentIndex == 0 {
                bookVC.pathSellingOrBuying = "selling"
            }else{
                bookVC.pathSellingOrBuying = "buying"
            }
            
        }
    }
}







