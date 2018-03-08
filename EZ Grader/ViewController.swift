//
//  ViewController.swift
//  EZ Grader
//
//  Copyright © 2018 RIT. All rights reserved.
//

import PDFKit

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    var pdfView: PDFView!
    let pdfFileName = "avg"
    var path: UIBezierPath!
    var currentAnnotation: PDFAnnotation!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let firstPageBtn = UIBarButtonItem(title: "<<", style: .plain, target: self, action: #selector(firstPage))
        let previousPageBtn = UIBarButtonItem(title: "<", style: .plain, target: self, action: #selector(previousPage))
        let nextPageBtn = UIBarButtonItem(title: ">", style: .plain, target: self, action: #selector(nextPage))
        let lastPageBtn = UIBarButtonItem(title: ">>", style: .plain, target: self, action: #selector(lastPage))
        let annotationsBtn = UIBarButtonItem(title: "Annotations", style: .plain, target: self, action: #selector(annotations))
        
        navigationItem.rightBarButtonItems = [lastPageBtn, nextPageBtn, previousPageBtn, firstPageBtn]
        navigationItem.leftBarButtonItems = [annotationsBtn]
        
        /*let documentProvider = UIDocumentPickerViewController(documentTypes: ["public.image", "public.audio", "public.movie", "public.text", "public.item", "public.content", "public.source-code"], in: .import)
        documentProvider.delegate = self as? UIDocumentPickerDelegate
        
        self.present(documentProvider, animated: true, completion: nil)*/
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func openPDFAction(_ sender: Any) {
        pdfView = PDFView(frame: UIScreen.main.bounds)
        
        if let url: URL = Bundle.main.url(forResource: pdfFileName, withExtension: "pdf") {
            if let pdfDocument: PDFDocument = PDFDocument(url: url) {
                pdfView.displayMode = .singlePage
                pdfView.autoScales = true
                pdfView.document = pdfDocument
                
                view.addSubview(pdfView)
            }
        }
    }
    
    @objc func firstPage() {
        pdfView.goToFirstPage(nil)
    }
    
    @objc func previousPage() {
        pdfView.goToPreviousPage(nil)
    }
    
    @objc func nextPage() {
        pdfView.goToNextPage(nil)
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
    }
    
    @objc func annotations() {
        if(pdfView.isUserInteractionEnabled) {
            path = UIBezierPath()
            path.lineWidth = 3
        } else {
            currentAnnotation = nil
        }

        pdfView.isUserInteractionEnabled = !pdfView.isUserInteractionEnabled
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchViewCoordinate: CGPoint = touch.location(in: pdfView)
            let pdfPageAtTouchedPosition: PDFPage = pdfView.page(for: touchViewCoordinate, nearest: true)!
            let touchPageCoordinate: CGPoint = pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
            
            path.move(to: touchPageCoordinate)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchViewCoordinate: CGPoint = touch.location(in: pdfView)
            let pdfPageAtTouchedPosition: PDFPage = pdfView.page(for: touchViewCoordinate, nearest: true)!
            let pdfPageIndexAtTouchedPosition: Int = (pdfView.document?.index(for: pdfPageAtTouchedPosition))!
            let touchPageCoordinate: CGPoint = pdfView.convert(touchViewCoordinate, to: pdfPageAtTouchedPosition)
            
            path.addLine(to: touchPageCoordinate)
            
            let rect: CGRect = path.bounds
            
            if( currentAnnotation != nil ) {
                pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.removeAnnotation(currentAnnotation)
            }
                
            currentAnnotation = PDFAnnotation(bounds: rect, forType: .ink, withProperties: nil)
            currentAnnotation.backgroundColor = .blue
            currentAnnotation.color = .black
            currentAnnotation.add(path)
            
            pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(currentAnnotation)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let touchViewCoordinate: CGPoint = touch.location(in: pdfView)
            let pdfPageAtTouchedPosition: PDFPage = pdfView.page(for: touchViewCoordinate, nearest: true)!
            let pdfPageIndexAtTouchedPosition: Int = (pdfView.document?.index(for: pdfPageAtTouchedPosition))!
            
            print(pdfView.document!.page(at: pdfPageIndexAtTouchedPosition)!.annotations.count)
        }
    }
}
