//
//  ViewController.swift
//  EZ Grader
//
//  Copyright © 2018 RIT. All rights reserved.
//

import PDFKit

class SelectFolderToGradeViewController: UIViewController {    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showGradePDFsViewControllerSegueId" {
            let pdfDocumentURLs: [URL] = Bundle.main.urls(forResourcesWithExtension: "pdf", subdirectory: nil)!
            
            var pdfDocument: PDFDocument!
            
            var numberOfPagesPerPDFDocument: Int!
            
            for pdfDocumentURL: URL in pdfDocumentURLs {
                pdfDocument = PDFDocument(url: pdfDocumentURL)
                
                if numberOfPagesPerPDFDocument == nil {
                    numberOfPagesPerPDFDocument = pdfDocument.pageCount
                } else if numberOfPagesPerPDFDocument != pdfDocument.pageCount {
                    // create the alert
                    let pdfDocumentPageCountMismatchUIAlertController: UIAlertController = UIAlertController(title: "PDF Document Page Count Mismatch", message: "All of the PDF documents to be graded must have the same number of pages.", preferredStyle: UIAlertControllerStyle.alert)
                    
                    // add the actions (buttons)
                    pdfDocumentPageCountMismatchUIAlertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                    
                    // show the alert
                    self.present(pdfDocumentPageCountMismatchUIAlertController, animated: true, completion: nil)
                    
                    return false
                }
            }
        }
        
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.isNavigationBarHidden = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
