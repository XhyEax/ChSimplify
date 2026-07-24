//
//  ImageSaver.swift
//  ChSimplify
//
//  保存图片到相册（仅添加权限），回调返回中文提示文案，供 toast 使用。
//

import UIKit
import Photos

enum ImageSaver {
    static func save(_ image: UIImage, completion: @escaping (String) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion("没有相册权限，请在设置中允许") }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    completion(success ? "已保存到相册"
                               : "保存失败：\(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }
}
