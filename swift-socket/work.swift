//
//  work.swift
//  swift-socket
//
//  Created by sss on 2018/4/30.
//  Copyright © 2018年 pom0o. All rights reserved.
//

import Foundation

var tSock: SzkSocket!;

func connect(){
    print("connectToServer ")
    tSock = SzkSocket("192.168.0.106",56789)
    tSock!.start(processReceivedData: processData)
    
    
}

func processData(data: String, length: Int){
    print("processData \(data) ")
}

func sendStr(str:String){
    if tSock != nil{
        tSock!.wrtie(string: str)
    }
}
