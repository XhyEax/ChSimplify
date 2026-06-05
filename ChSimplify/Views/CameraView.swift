//
//  CameraView.swift
//  ChSimplify
//
//  自定义相机：拍照后立即返回图片，不显示系统的「重拍 / 使用照片」确认页。
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = { image in
            onCapture(image)
            dismiss()
        }
        controller.onCancel = { dismiss() }
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

final class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onCapture: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "com.chsimplify.camera.session")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPreviewAndControls()
        sessionQueue.async { [weak self] in
            self?.configureSession()
            self?.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()
    }

    private func setupPreviewAndControls() {
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        let shutter = UIButton(type: .system)
        shutter.translatesAutoresizingMaskIntoConstraints = false
        shutter.backgroundColor = .white
        shutter.layer.cornerRadius = 35
        shutter.layer.borderColor = UIColor.lightGray.cgColor
        shutter.layer.borderWidth = 4
        shutter.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(shutter)

        let cancel = UIButton(type: .system)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.setTitle("取消", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancel)

        NSLayoutConstraint.activate([
            shutter.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            shutter.widthAnchor.constraint(equalToConstant: 70),
            shutter.heightAnchor.constraint(equalToConstant: 70),
            cancel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancel.centerYAnchor.constraint(equalTo: shutter.centerYAnchor),
        ])
    }

    @objc private func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onCapture?(image)
        }
    }
}
