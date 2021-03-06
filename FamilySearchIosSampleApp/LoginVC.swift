//
//  LoginVC.swift
//  FamilySearchIosSampleApp
//
//  Created by Eduardo Flores on 6/3/16.
//  Copyright © 2016 FamilySearch. All rights reserved.
//

import UIKit

class LoginVC: UIViewController {
    
    @IBOutlet weak var usernameTextFiew: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButtonOutlet: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var dataUsageLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator.stopAnimating()
        
        usernameTextFiew.placeholder = NSLocalizedString("usernamePlaceholderText", comment: "username, in email form")
        passwordTextField.placeholder = NSLocalizedString("passwordPlaceholderText", comment: "password")
        loginButtonOutlet.setTitle(NSLocalizedString("loginText", comment: "text for login button"), forState: UIControlState.Normal)
        dataUsageLabel.text = NSLocalizedString("loginDataUsage", comment: "description of data usage")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func loginAction(sender: AnyObject)
    {
        activityIndicator.startAnimating()
        
        guard let
            username = usernameTextFiew.text,
            password = passwordTextField.text
            where !username.isEmpty && !password.isEmpty
            else {
                // TODO: display error for empty username or password
                return
        }

        // get initial GET call to collections
        Utilities.getUrlsFromCollections({ [weak self] (collectionsResponse, error) -> Void in
            
            guard error == nil else {
                print("Error getting collections data from server. Error = \(error?.description)")
                self?.activityIndicator.stopAnimating()
                return
            }

            // get the login token
            self?.getToken(collectionsResponse.tokenUrlString!,
                username: username,
                password: password,
                client_id: AppKeys.API_KEY,
                completionToken: {(responseToken, errorToken) -> Void in
                    guard errorToken == nil else {
                        // TODO: handle case when somehow the token is nil
                        return
                    }

                    // get user data, with the newly acquired token
                    self?.getCurrentUserData(collectionsResponse.currentUserString!,
                        accessToken: responseToken!,
                        completionCurrentUser:{(responseUser, errorUser) -> Void in
                            guard errorToken == nil else {
                                // TODO: handle case when somehow the user data is nil
                                return
                            }
                            // all login data needed has been downloaded
                            // push to the next view controller, in the main thread
                            dispatch_async(dispatch_get_main_queue(),{
                                [weak self] in
                                self?.performSegueWithIdentifier("segueToTabBar", sender: responseUser)
                            })
                            
                    })
                    
                }
            )
        })
    }
    
    func getToken(tokenUrlAsString : String, username : String, password : String, client_id : String, completionToken:(responseToken:String?, errorToken:NSError?) -> ()) {
        let grant_type = "password";
        
        let params = "?username=" + username +
            "&password=" + password +
            "&grant_type=" + grant_type +
            "&client_id=" + AppKeys.API_KEY;
        
        let urlAsString = tokenUrlAsString + params
        
        // create the post request
        let request = NSMutableURLRequest(URL: NSURL(string: urlAsString)!)
        request.HTTPMethod = "POST"
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request){ data, response, error in
            guard error == nil else {
                print("Error downloading token. Error: \(error)")
                completionToken(responseToken: nil, errorToken: error)
                return
            }
            do
            {
                let jsonToken = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments);
                if let token = jsonToken["access_token"] as? String
                {
                    // parse the json to get the access_token, and save this token in NSUserDefaults
                    let preferences = NSUserDefaults.standardUserDefaults()
                    preferences.setValue(token, forKey: Utilities.KEY_ACCESS_TOKEN)
                    preferences.synchronize()
                
                    completionToken(responseToken: token, errorToken: nil)
                }
            }
            catch
            {
                print("Error parsing token JSON. Error: \(error)");
            }
                
        }
        
        task.resume()
    }
    
    // get the user data
    func getCurrentUserData(currentUserUrlString : String, accessToken : String, completionCurrentUser:(responseUser:User?, errorUser:NSError?) -> ())
    {
        let currentUserUrl = NSURL(string: currentUserUrlString);
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration();
        let headers: [NSObject : AnyObject] = ["Accept":"application/json", "Authorization":"Bearer " + accessToken];
        configuration.HTTPAdditionalHeaders = headers;
        let session = NSURLSession(configuration: configuration)
        
        let currentUserTask = session.dataTaskWithURL(currentUserUrl!) { (data, currentUserResponse, errorUserData) in
            // parse the currentUser data
            do
            {
                let currentUserJson = try NSJSONSerialization.JSONObjectWithData(data!, options: .AllowFragments);
                
                if let usersJsonObject = currentUserJson["users"] as? [[String : AnyObject]]
                {
                    let user = User()
                    
                    if let userJsonObject = usersJsonObject.first
                    {
                        user.id = userJsonObject["id"] as? String
                        user.contactName = userJsonObject["contactName"] as? String
                        user.helperAccessPin = userJsonObject["helperAccessPin"] as? String
                        user.givenName = userJsonObject["givenName"] as? String
                        user.familyName = userJsonObject["familyName"] as? String
                        user.email = userJsonObject["email"] as? String
                        user.country = userJsonObject["country"] as? String
                        user.gender = userJsonObject["gender"] as? String
                        user.birthDate = userJsonObject["birthDate"] as? String
                        user.phoneNumber = userJsonObject["phoneNumber"] as? String
                        user.mailingAddress = userJsonObject["mailingAddress"] as? String
                        user.preferredLanguage = userJsonObject["preferredLanguage"] as? String
                        user.displayName = userJsonObject["displayName"] as? String
                        user.personId = userJsonObject["personId"] as? String
                        user.treeUserId = userJsonObject["treeUserId"] as? String
                        
                        // The Memories activity will need the URL that comes from user.links.artifact.href
                        // in order to get the memories data
                        let links = userJsonObject["links"] as? NSDictionary
                        let artifacts = links!["artifacts"] as? NSDictionary
                        user.artifactsHref = artifacts!["href"] as? String
                        
                        completionCurrentUser(responseUser:user, errorUser:nil)
                        
                        return
                    }
                    else
                    {
                        print("The user JSON does not contain any data")
                    }
                    
                    completionCurrentUser(responseUser:nil, errorUser:nil)
                }

            }
            catch
            {
                completionCurrentUser(responseUser:nil, errorUser:errorUserData)
            }
        }
        currentUserTask.resume()
        
    }
    
// MARK: - Segue methods
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        if (segue.identifier == "segueToTabBar")
        {
            let tabBarController : UITabBarController = (segue.destinationViewController as? UITabBarController)!
            tabBarController.tabBar.items![0].title = NSLocalizedString("tabAncestorsName", comment: "name for list tab")
            tabBarController.tabBar.items![1].title = NSLocalizedString("tabMemoriesName", comment: "name for memories tab")
            
            guard let treeTVC = tabBarController.viewControllers?[0] as? TreeTVC else {
                fatalError("The first viewController in the tabBarController should be an instance of TreeTVC")
            }
            // need to pass a User object to the tree table view controller
            treeTVC.user = sender as? User
            
            guard let memoriesVC = tabBarController.viewControllers?[1] as? MemoriesVC else {
                fatalError("The second viewController in the tabBarController should be an instance of MemoriesVC")
            }
            memoriesVC.user = sender as? User
            
            self.activityIndicator.stopAnimating()
        }
    }
}







































