//
//  CatsViewController.swift
//  IceCream_Example
//
//  Created by 蔡越 on 22/05/2018.
//  Copyright © 2018 蔡越. All rights reserved.
//

import UIKit
import RealmSwift
import IceCream

class CatsViewController: UIViewController {
    var notificationToken: NotificationToken? = nil
    var cats:Results<Cat>!
    let realm = try! Realm()
    
    lazy var addBarItem: UIBarButtonItem = {
        let b = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.add, target: self, action: #selector(add))
        return b
    }()
    
    lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.delegate = self
        tv.dataSource = self
        return tv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        navigationItem.rightBarButtonItem = addBarItem
        title = "Cats"
        
        bind()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.frame
    }
    
    func bind() {
        let realm = try! Realm()
        
        /// Results instances are live, auto-updating views into the underlying data, which means results never have to be re-fetched.
        /// https://realm.io/docs/swift/latest/#objects-with-primary-keys
        cats = realm.objects(Cat.self)
            .filter("isDeleted = false")
            .sorted(byKeyPath: "id")
        
        notificationToken = cats.observe({ [weak self] (changes) in
            guard let tableView = self?.tableView else { return }
            
            switch changes {
            case .initial(_):
                tableView.reloadData()
            case .update(_, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                tableView.beginUpdates()
                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}),
                                     with: .automatic)
                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }),
                                     with: .automatic)
                tableView.endUpdates()
            case .error(let error):
                fatalError("\(error)")
            }
        })
    }
    
    @objc func add() {
        let cat = Cat()
        cat.name = String(format: "Cat %0d", cats.count + 1)
        
        let data = UIImage(named: cat.age % 2 == 1 ? "heart_cat" : "dull_cat")!.pngData()
        cat.avatar = CreamAsset.create(object: cat, propName: Cat.AVATAR_KEY, data: data!)
        
        try! realm.write {
            realm.add(cat)
        }
    }
    
    deinit {
        notificationToken?.invalidate()
    }
}

extension CatsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { (_, ip) in
            let alert = UIAlertController(title: NSLocalizedString("caution", comment: "caution"), message: NSLocalizedString("sure_to_delete", comment: "sure_to_delete"), preferredStyle: .alert)
            let deleteAction = UIAlertAction(title: NSLocalizedString("delete", comment: "delete"), style: .destructive, handler: { (action) in
                guard ip.row < self.cats.count else { return }
                let cat = self.cats[ip.row]
                try! self.realm.write {
                    cat.isDeleted = true
                }
            })
            let defaultAction = UIAlertAction(title: NSLocalizedString("cancel", comment: "cancel"), style: .default, handler: nil)
            alert.addAction(defaultAction)
            alert.addAction(deleteAction)
            self.present(alert, animated: true, completion: nil)
        }
        
        let archiveAction = UITableViewRowAction(style: .normal, title: "Plus") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]
            try! `self`.realm.write {
                cat.age += 1
            }
        }
        let changeImageAction = UITableViewRowAction(style: .normal, title: "Change Img") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]
            try! `self`.realm.write {
                if let imageData = UIImage(named: cat.age % 2 == 0 ? "heart_cat" : "dull_cat")!.jpegData(compressionQuality: 1.0) {
                    cat.avatar = CreamAsset.create(object: cat, propName: Cat.AVATAR_KEY, data: imageData)
                }
            }
        }
        changeImageAction.backgroundColor = .blue
        let emptyImageAction = UITableViewRowAction(style: .normal, title: "Nil Img") { [weak self](_, ip) in
            guard let `self` = self else { return }
            guard ip.row < `self`.cats.count else { return }
            let cat = `self`.cats[ip.row]
            try! `self`.realm.write {
                cat.avatar = nil
            }
        }
        emptyImageAction.backgroundColor = .purple
        return [deleteAction, archiveAction, changeImageAction, emptyImageAction]
    }
}

extension CatsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cats.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        let price = String(format: "%.2f", cats[indexPath.row].price.doubleValue)
        cell?.textLabel?.text = cats[indexPath.row].name + " Age: \(cats[indexPath.row].age)" + " Price: \(price)"
        if let data = cats[indexPath.row].avatar?.storedData() {
            cell?.imageView?.image = UIImage(data: data)
        } else {
            cell?.imageView?.image = UIImage(named: "cat_placeholder")
        }
        return cell ?? UITableViewCell()
    }
}
