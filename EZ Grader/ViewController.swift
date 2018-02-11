//
//  ViewController.swift
//  EZ Grader
//
//  Created by admin on 1/29/18.
//  Copyright © 2018 RIT. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    let pdfFileName = "swift_tutorial"

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func openPDFAction(_ sender: Any) {
        if let url = Bundle.main.url(forResource: pdfFileName, withExtension: "pdf") {
            let webView = UIWebView(frame: self.view.frame)
            let urlRequest = URLRequest(url: url)
            webView.loadRequest(urlRequest as URLRequest)
            self.view.addSubview(webView)
            
            let pdfViewController = UIViewController()
            pdfViewController.view.addSubview(webView)
            pdfViewController.title = pdfFileName
            self.navigationController?.pushViewController(pdfViewController, animated: true)
        }
    }
}

