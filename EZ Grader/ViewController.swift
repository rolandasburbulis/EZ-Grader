//
//  ViewController.swift
//  EZ Grader
//
//  Copyright © 2018 RIT. All rights reserved.
//

import PDFKit

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    // store our PDFView in a property so we can manipulate it later
    var pdfView: PDFView!
    let pdfFileName = "swift_tutorial"
    var signingPath: UIBezierPath!
    var annotationAdded: Bool!
    var currentAnnotation: PDFAnnotation!

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
        // create the alert
        let alert = UIAlertController(title: "Number of pages in PDF", message: "\(pdfView.document!.pageCount)", preferredStyle: UIAlertControllerStyle.alert)
        
        // add the actions (buttons)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        
        // show the alert
        self.present(alert, animated: true, completion: nil)
        
        //let fileManager = FileManager.default
        
        // Get contents in directory: '.' (current one)
        /*
        do {
            let files = try fileManager.contentsOfDirectory(atPath: Bundle.main.bundlePath)
                
                //+ "/EZ Grader")
            print(files)
        }
        catch let error as NSError {
            print("Ooops! Something went wrong: \(error)")
        }*/
    }
    
    @objc func annotations() {
        pdfView.isUserInteractionEnabled = !pdfView.isUserInteractionEnabled
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            annotationAdded = false
            
            let touchViewCoordinate: CGPoint = touch.location(in: pdfView)
            let pdfPageAtTouchedPosition: PDFPage = pdfView.page(for: touchViewCoordinate, nearest: true)!
            let touchPageCoordinate: CGPoint = pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
            
            signingPath = UIBezierPath()
            signingPath.move(to: touchPageCoordinate)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchViewCoordinate: CGPoint = touch.location(in: pdfView)
            let pdfPageAtTouchedPosition: PDFPage = pdfView.page(for: touchViewCoordinate, nearest: true)!
            let touchPageCoordinate: CGPoint = pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
            
            signingPath.addLine(to: touchPageCoordinate)
            
            let rect: CGRect = signingPath.bounds
            
            if( annotationAdded ) {
                pdfView.document?.page(at: 0)?.removeAnnotation(currentAnnotation)
            }
                
            currentAnnotation = PDFAnnotation(bounds: rect, forType: .ink, withProperties: nil)
            currentAnnotation.backgroundColor = .blue
            currentAnnotation.color = .black
            currentAnnotation.add(signingPath)
            
            annotationAdded = true
            
            pdfView.document?.page(at: 0)?.addAnnotation(currentAnnotation)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let position = touch.location(in: pdfView)
            signingPath.addLine(to: pdfView.convert(position, to: pdfView.page(for: position, nearest: true)!))
            
            pdfView.document?.page(at: 0)?.removeAnnotation(currentAnnotation)
            
            let rect = signingPath.bounds
            let annotation = PDFAnnotation(bounds: rect, forType: .ink, withProperties: nil)
            annotation.backgroundColor = .blue
            annotation.color = .black
            annotation.add(signingPath)
            pdfView.document?.page(at: 0)?.addAnnotation(annotation)
        }
        
        print(pdfView.document!.page(at: 0)!.annotations.count)
    }
}
