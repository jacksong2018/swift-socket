//
//  ViewController.swift
//  swift-socket
//
//  Created by sss on 2018/4/30.
//  Copyright © 2018年 pom0o. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func connectToServer(_ sender: AnyObject){
        print("createThread")
        connect()
    }
    
    @IBAction func sendDataToServer(_ sender: AnyObject){
        print("sendDataToServer")
        let str = "hello"
        sendStr(str: str)
    }

}

