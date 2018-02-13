//
//  ViewController.swift
//  EZ Grader
//
//  Created by admin on 1/29/18.
//  Copyright © 2018 RIT. All rights reserved.
//

//import UIKit
import PDFKit

class ViewController: UIViewController {
    // store our PDFView in a property so we can manipulate it later
    var pdfView: PDFView!
    let pdfFileName = "swift_tutorial"

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let firstPageBtn = UIBarButtonItem(title: "First", style: .plain, target: self, action: #selector(firstPage))
        let lastPageBtn = UIBarButtonItem(title: "Last", style: .plain, target: self, action: #selector(lastPage))
        let numberOfPagesBtn = UIBarButtonItem(title: "Number of pages", style: .plain, target: self, action: #selector(numberOfPages))
        let annotationsBtn = UIBarButtonItem(title: "Annotations", style: .plain, target: self, action: #selector(annotations))
        
        navigationItem.rightBarButtonItems = [firstPageBtn, lastPageBtn, numberOfPagesBtn, annotationsBtn]
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func openPDFAction(_ sender: Any) {
        // create and add the PDF view
        pdfView = PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pdfView)
        
        // make it take up the full screen
        pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        pdfView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        // load our example PDF and make it display immediately
        let url = Bundle.main.url(forResource: pdfFileName, withExtension: "pdf")!
        
        pdfView.document = PDFDocument(url: url)
    }
    
    @objc func firstPage() {
        pdfView.goToFirstPage(nil)
    }
    
    @objc func lastPage() {
        pdfView.goToLastPage(nil)
    }
    
    @objc func numberOfPages() {
        print(pdfView.document?.pageCount ?? 0)
        
        let fileManager = FileManager.default
        
        // Get contents in directory: '.' (current one)
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: Bundle.main.bundlePath)
                
                //+ "/EZ Grader")
            print(files)
        }
        catch let error as NSError {
            print("Ooops! Something went wrong: \(error)")
        }
    }
    
    @objc func annotations() {
        print(pdfView.document?.page(at: 0)?.annotations.count)

        let rect = CGRect(x: 100.0, y: 100.0, width: 100.0, height: 100.0)
        
        let annotation = PDFAnnotation(bounds: rect, forType: .ink, withProperties: nil)
        annotation.backgroundColor = .blue
        
        let pathRect = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
        let path = UIBezierPath(ovalIn: pathRect)
        annotation.add(path)
        
        // Add annotation to the first page
        pdfView.document?.page(at: 0)?.addAnnotation(annotation)
        

        
        print(pdfView.document?.page(at: 0)?.annotations.count)
    }
}
