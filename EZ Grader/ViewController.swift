//
//  ViewController.swift
//  EZ Grader
//
//  Copyright © 2018 RIT. All rights reserved.
//

import PDFKit

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    var pdfView: PDFView!
    var path: UIBezierPath!
    var currentAnnotation: PDFAnnotation!
    var numberOfPagesPerDoc: Int!
    var perPageCombined: PDFDocument!
    var perStudentCombined: PDFDocument!
    var isPerPageMode: Bool = true

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let firstPageBtn = UIBarButtonItem(title: "<<", style: .plain, target: self, action: #selector(firstPage))
        let previousPageBtn = UIBarButtonItem(title: "<", style: .plain, target: self, action: #selector(previousPage))
        let nextPageBtn = UIBarButtonItem(title: ">", style: .plain, target: self, action: #selector(nextPage))
        let lastPageBtn = UIBarButtonItem(title: ">>", style: .plain, target: self, action: #selector(lastPage))
        let annotationsBtn = UIBarButtonItem(title: "Annotate", style: .plain, target: self, action: #selector(annotations))
        let perPageBtn = UIBarButtonItem(title: "Per Page", style: .plain, target: self, action: #selector(viewPerPage))
        let perStudentBtn = UIBarButtonItem(title: "Per Student", style: .plain, target: self, action: #selector(viewPerStudent))
        let saveBtn = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(save))
        
        navigationItem.rightBarButtonItems = [lastPageBtn, nextPageBtn, previousPageBtn, firstPageBtn]
        navigationItem.leftBarButtonItems = [annotationsBtn, perPageBtn, perStudentBtn, saveBtn]
        
        /*let documentProvider = UIDocumentPickerViewController(documentTypes: ["public.image", "public.audio", "public.movie", "public.text", "public.item", "public.content", "public.source-code"], in: .import)
        documentProvider.delegate = self as? UIDocumentPickerDelegate
        
        self.present(documentProvider, animated: true, completion: nil)*/
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func openPDFAction(_ sender: Any) {
        let pdfDocumentUrls: [URL] = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: nil)!
        
        var pdfDocument: PDFDocument!
        var mismatchedNumberOfPagesDetected: Bool = false
        
        for pdfDocumentUrl: URL in pdfDocumentUrls {
            pdfDocument = PDFDocument(url: pdfDocumentUrl)
            
            if numberOfPagesPerDoc == nil {
                numberOfPagesPerDoc = pdfDocument.pageCount
            } else if numberOfPagesPerDoc != pdfDocument.pageCount {
                mismatchedNumberOfPagesDetected = true
                
                // create the alert
                let alert = UIAlertController(title: "Page Count Mismatch", message: "All of the documents to be graded must have the same number of pages." + ".", preferredStyle: UIAlertControllerStyle.alert)
                
                // add the actions (buttons)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                
                // show the alert
                self.present(alert, animated: true, completion: nil)
                
                break
            }
        }
        
        if !mismatchedNumberOfPagesDetected {
            perStudentCombined = PDFDocument()
            perPageCombined = PDFDocument()
            
            for pdfDocumentUrl: URL in pdfDocumentUrls {
                pdfDocument = PDFDocument(url: pdfDocumentUrl)
                
                var pageIndex: Int = 0
                
                while pageIndex < pdfDocument.pageCount {
                    perStudentCombined.insert(pdfDocument.page(at: pageIndex)!.copy() as! PDFPage, at: perStudentCombined.pageCount)
                    
                    pageIndex += 1
                }
            }
            
            var pageIndex: Int = 0
            
            while pageIndex < numberOfPagesPerDoc {
                for pdfDocumentUrl: URL in pdfDocumentUrls {
                    let pdfPage: PDFPage = (PDFDocument(url: pdfDocumentUrl)!.page(at: pageIndex))!.copy() as! PDFPage
                    
                    perPageCombined.insert(pdfPage, at: perPageCombined.pageCount)
                }
                
                pageIndex += 1
            }
            
            pdfView = PDFView(frame: UIScreen.main.bounds)
            
            pdfView.displayMode = .singlePageContinuous
            pdfView.autoScales = true
            pdfView.document = perPageCombined
            
            view.addSubview(pdfView)
        }
        
        /*if let url: URL = Bundle.main.url(forResource: pdfFileName, withExtension: "pdf") {
            if let pdfDocument: PDFDocument = PDFDocument(url: url) {
                pdfView.displayMode = .singlePage
                pdfView.autoScales = true
                pdfView.document = pdfDocument
                
                view.addSubview(pdfView)
            }
        }*/
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
    
    @objc func annotations() {
        if(pdfView.isUserInteractionEnabled) {
            path = UIBezierPath()
            path.lineWidth = 3
        } else {
            currentAnnotation = nil
        }

        pdfView.isUserInteractionEnabled = !pdfView.isUserInteractionEnabled
    }
    
    @objc func viewPerPage() {
        pdfView.document = perPageCombined
        
        isPerPageMode = true
    }
    
    @objc func viewPerStudent() {
        pdfView.document = perStudentCombined
        
        isPerPageMode = false
    }
    
    @objc func save() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        var docToWriteOut: PDFDocument = PDFDocument()
    
        if isPerPageMode {
            let numberOfDocuments: Int = perPageCombined.pageCount / numberOfPagesPerDoc
            
            for documentNumber: Int in 0...numberOfDocuments - 1 {
                for pageNumber: Int in 0...numberOfPagesPerDoc - 1 {
                    docToWriteOut.insert(perPageCombined.page(at: (pageNumber * numberOfDocuments + documentNumber))!.copy() as! PDFPage, at: docToWriteOut.pageCount)
                }
                
                docToWriteOut.write(toFile: "\(documentsPath)/output\(documentNumber + 1).pdf")
                docToWriteOut = PDFDocument()
            }
        } else {
            for pageIndex: Int in 1...perStudentCombined.pageCount {
                docToWriteOut.insert(perStudentCombined.page(at: pageIndex - 1)!.copy() as! PDFPage, at: docToWriteOut.pageCount)
                
                if pageIndex % numberOfPagesPerDoc == 0 {
                    docToWriteOut.write(toFile: "\(documentsPath)/output\(pageIndex / numberOfPagesPerDoc).pdf")
                    docToWriteOut = PDFDocument()
                }
            }
        }
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
            
            if( currentAnnotation != nil ) {
                pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.removeAnnotation(currentAnnotation)
            }
                
            currentAnnotation = PDFAnnotation(bounds: pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox), forType: .ink, withProperties: nil)
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
            
            //let bounds = pdfPageAtTouchedPosition.bounds(for: PDFDisplayBox.cropBox)
            
            /*let textFieldNameBox = CGRect(origin: CGPoint(x: 169, y: bounds.height - 102), size: CGSize(width: 371, height: 23))

            let textFieldName = PDFAnnotation(bounds: textFieldNameBox, forType: .widget, withProperties: nil)
            
            textFieldName.widgetFieldType = .button
            textFieldName.backgroundColor = UIColor.blue
            
            pdfView.document?.page(at: pdfPageIndexAtTouchedPosition)?.addAnnotation(textFieldName);*/
        }
    }
}
