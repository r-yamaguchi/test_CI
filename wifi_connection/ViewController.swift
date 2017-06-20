//
//  ViewController.swift
//  wifi_connection
//
//  Created by FNDM04 on 2017/05/31.
//  Copyright © 2017年 froide.co.jp. All rights reserved.
//

import UIKit
import Alamofire
import ReachabilitySwift
import SystemConfiguration.CaptiveNetwork

class ViewController: UIViewController {

    @IBOutlet weak var networkName: UILabel!
    @IBOutlet weak var wifiName: UILabel!
    
    let wifiNotification = NSNotification.Name("wifiNotification")
    let reachability = Reachability()!
    var wifiname: String = ""
    var loginFlag = false
    var logoutFlag = false
    var pushLogoutFlag = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 2.0杪ごとにSSIDの変化を監視
        Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(self.getWiFiName), userInfo: nil, repeats: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(self.reachabilityChanged), name: ReachabilityChangedNotification, object: reachability)
        do {
            try reachability.startNotifier()
        } catch {
            print("could not start reachability notifier")
        }
        getWiFiName()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //　現在接続しているSSIDを取得
    func getWiFiName() {
        if getSSID() != nil {
            wifiname = getSSID()!
            wifiName.text = wifiname
            print("my network is \(String(describing: wifiname))")
            wifiControl()
        } else {
            if logoutFlag == false {
                print("============== This is not Wi2premium =================")
                print("============== Logout Wi2WiFi ==============")
                wi2Logout()
            }
            wifiName.text = "なし"
            print("no wifi name")
            pushLogoutFlag = false
            return
        }
    }
    
    // 現在接続中のwifiが "wi2premium"であればWifi接続メソッドを投げる
    func wifiControl(){
        print("wifiname: \(wifiname)")
        print("Loginflag:\(loginFlag)")
        print("pushLogoutflag: \(pushLogoutFlag)")
        print("Logoutflag:\(logoutFlag)")
        
        if wifiname == "Wi2premium" {
            if loginFlag == false {
                if logoutFlag == true {
                    if pushLogoutFlag == true {
                        print("============= This is Wi2premium, after push '接続解除'")
                        return
                    }
                    print("============== Connect Wi2Wifi =================")
                    wi2Login()
                    return
                }
                if pushLogoutFlag == true {
                    print("============== Do not execute wi2Login(), Now Connecting 'Wi2premium' ==================")
                    return
                }
                print("============== Connect Wi2Wifi =================")
                wi2Login()
                return
            }
            if pushLogoutFlag == true {
                print("============= This is Wi2premium, after push '接続解除'")
                return
            }
            print("============== Do not execute wi2Login(), Now Connecting 'Wi2premium' ==================")
            return
        }else { // Wi2以外のネットワーク
            if loginFlag == true { // Wi2ログアウト未処理　→ ログアウト
                print("============== This is not Wi2premium =================")
                print("============== Logout Wi2WiFi ==============")
                wi2Logout()
                return
            }
            print("============== This is not Wi2premium =================")
            return
        }
    }

    
    // WiFi接続認証通信
    func wi2Login() {
        let login_params = ["username": "xxxxxx", "password": "xxxxxx"]
        let parameters: [String: Any] = [
            "login_method": "username",
            "login_params": login_params
        ]
        // Cookieの取得
        let COOKIE_URL = "https://service.wi2.ne.jp/wi2auth/odakyu/index.html"
        let cookie_url = URL(string: COOKIE_URL)
        Alamofire.request(COOKIE_URL, method: .get).responseJSON { response -> Void in
            // エラー処理
            guard let res = response.response else{
                print("Can not catch response from API")
                return
            }
            // Cookie保存
            print("res: \(String(describing: res))")
            let get_cookies = HTTPCookie.cookies(withResponseHeaderFields: res.allHeaderFields as! [String : String], for: (res.url)! )
            for i in 0 ..< get_cookies.count {
                let cookie = get_cookies[i]
                
                HTTPCookieStorage.shared.setCookie(cookie)
                print("Cookies\(i): \(cookie)")
            }
            // Cookieを渡す
            let AUTH_URL = "https://service.wi2.ne.jp/wi2auth/xhr/login"
            let cookies = HTTPCookieStorage.shared.cookies(for: cookie_url! as URL)
            let header  = HTTPCookie.requestHeaderFields(with: cookies!)
            print("header: \(header as Any)")
            
            Alamofire.request( AUTH_URL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: header)
                .responseJSON { response in
                    print("Response: \(response.response as Any)") // HTTP URL response
                    print("Data: \(response.data as Any)")     // server data
                    print("Result: \(response.result)")   // result of response serialization
                    print("Error: \(response.error as Any)")
                    
                    if let JSON = response.result.value {
                        print("JSON: \(JSON)")
                    }
            }
        }
        loginFlag = true
        logoutFlag = false
        pushLogoutFlag = false
    }
    
    // WiFi接続解除通信
    func wi2Logout() {
        let AUTH_URL = "https://service.wi2.ne.jp/wi2auth/xhr/logout"
        Alamofire.request(AUTH_URL, method: .get).responseJSON { response -> Void in
            print("================= Logout ===============")
            print("Response: \(response.response as Any)") // HTTP URL response
            print("Data: \(response.data as Any)")     // server data
            print("Result: \(response.result)")   // result of response serialization
            print("Error: \(response.error as Any)")
            
            if let JSON = response.result.value {
                print("JSON: \(JSON)")
            }
        }
        loginFlag = false
        logoutFlag = true
    }

    // 接続ネットワークを探す
    func reachabilityChanged(note: NSNotification) {
        NotificationCenter.default.post(name: wifiNotification, object: nil)
        let reachability = note.object as! Reachability
        if reachability.isReachable {
            if reachability.isReachableViaWiFi {
                networkName.text = "WiFi"
                print("WIFI")
            } else {
                networkName.text = "LTE/3G"
                print("LTE/3G")
            }
        } else {
            networkName.text = "なし"
            print("なし")
        }
    }
    
    // 現在接続中のWifiのSSIDを取得
    func getSSID() -> String? {
        let interfaces = CNCopySupportedInterfaces()
        if interfaces == nil {
            return nil
        }
        let interfacesArray = interfaces as! [String]
        if interfacesArray.count <= 0 {
            return nil
        }
        let interfaceName = interfacesArray[0] as String
        let unsafeInterfaceData = CNCopyCurrentNetworkInfo(interfaceName as CFString)
        if unsafeInterfaceData == nil {
            return nil
        }
        let interfaceData = unsafeInterfaceData as! Dictionary <String,AnyObject>
        return interfaceData["SSID"] as? String
    }
    
    // "接続"を押した時の処理
    @IBAction func connectWiFi(_ sender: Any) {
        print("============== 接続 ===============")
        loginFlag = false
        pushLogoutFlag = false
        getWiFiName()
    }
    
    //  "接続解除を押した時の処理"
    @IBAction func disConnectWiFi(_ sender: Any) {
        wi2Logout()
        pushLogoutFlag = true
    }
}

