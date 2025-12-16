//
//  StickerStyleProcessor.swift
//  meta-stickers
//
//  Applies style settings to sticker images after segmentation.
//

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct StickerStyleSettings {
    var style: AppSettings.StickerStyle
    var borderWidth: Double
    var borderColor: UIColor
    var shadowEnabled: Bool
    var shadowOpacity: Double

    init(from appSettings: AppSettings?) {
        self.style = AppSettings.StickerStyle(rawValue: appSettings?.stickerStyle ?? "default") ?? .default

        // Use preset-based values instead of custom settings
        switch self.style {
        case .default:
            self.borderWidth = 0
            self.borderColor = .white
            self.shadowEnabled = true
            self.shadowOpacity = 0.25

        case .outlined:
            self.borderWidth = 4
            self.borderColor = .white
            self.shadowEnabled = true
            self.shadowOpacity = 0.3

        case .gpuOutline:
            self.borderWidth = 5
            self.borderColor = .white
            self.shadowEnabled = true
            self.shadowOpacity = 0.25

        case .cartoon:
            self.borderWidth = 3
            self.borderColor = .black
            self.shadowEnabled = false
            self.shadowOpacity = 0

        case .minimal:
            self.borderWidth = 0
            self.borderColor = .white
            self.shadowEnabled = false
            self.shadowOpacity = 0

        case .glossy:
            self.borderWidth = 0
            self.borderColor = .white
            self.shadowEnabled = true
            self.shadowOpacity = 0.35

        case .vintage:
            self.borderWidth = 2
            self.borderColor = UIColor(white: 0.9, alpha: 1.0)
            self.shadowEnabled = true
            self.shadowOpacity = 0.2
        }
    }

    static var `default`: StickerStyleSettings {
        StickerStyleSettings(from: nil)
    }
}

class StickerStyleProcessor {

    private let context = CIContext()

    /// Apply all style settings to a sticker image
    func applyStyle(to image: UIImage, settings: StickerStyleSettings) -> UIImage {
        var processedImage = image

        // 1. Apply style preset effects (color adjustments, etc.)
        processedImage = applyStylePreset(to: processedImage, style: settings.style)

        // 2. Apply border if the preset includes one
        if settings.borderWidth > 0 {
            if settings.style.usesGPUBorder {
                processedImage = addBorderGPU(to: processedImage, width: settings.borderWidth, color: settings.borderColor)
            } else {
                processedImage = addBorder(to: processedImage, width: settings.borderWidth, color: settings.borderColor)
            }
        }

        // 3. Apply shadow if the preset includes one
        if settings.shadowEnabled {
            processedImage = addShadow(to: processedImage, opacity: settings.shadowOpacity)
        }

        return processedImage
    }

    // MARK: - Style Presets

    private func applyStylePreset(to image: UIImage, style: AppSettings.StickerStyle) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        var outputImage: CIImage = ciImage

        switch style {
        case .default:
            // No additional processing
            return image

        case .outlined:
            // Outlined effect is handled by border, just return original
            return image

        case .gpuOutline:
            // GPU outline effect is handled by border, just return original
            return image

        case .cartoon:
            // Boost saturation and contrast for cartoon effect
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(ciImage, forKey: kCIInputImageKey)
                colorControls.setValue(1.3, forKey: kCIInputSaturationKey)
                colorControls.setValue(1.2, forKey: kCIInputContrastKey)
                if let result = colorControls.outputImage {
                    outputImage = result
                }
            }

        case .minimal:
            // Slightly reduce saturation for cleaner look
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(ciImage, forKey: kCIInputImageKey)
                colorControls.setValue(0.9, forKey: kCIInputSaturationKey)
                if let result = colorControls.outputImage {
                    outputImage = result
                }
            }

        case .glossy:
            // Add highlight/bloom effect
            if let bloom = CIFilter(name: "CIBloom") {
                bloom.setValue(ciImage, forKey: kCIInputImageKey)
                bloom.setValue(2.0, forKey: kCIInputRadiusKey)
                bloom.setValue(0.5, forKey: kCIInputIntensityKey)
                if let result = bloom.outputImage {
                    outputImage = result
                }
            }

        case .vintage:
            // Sepia tone + fade effect
            if let sepia = CIFilter(name: "CISepiaTone") {
                sepia.setValue(ciImage, forKey: kCIInputImageKey)
                sepia.setValue(0.4, forKey: kCIInputIntensityKey)
                if let result = sepia.outputImage {
                    outputImage = result
                }
            }
            // Add slight fade
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(outputImage, forKey: kCIInputImageKey)
                colorControls.setValue(0.9, forKey: kCIInputContrastKey)
                colorControls.setValue(0.05, forKey: kCIInputBrightnessKey)
                if let result = colorControls.outputImage {
                    outputImage = result
                }
            }
        }

        // Render the CIImage back to UIImage
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }

        return image
    }

    // MARK: - Border (Edge-following)

    /// Adds an outline border that follows the shape of the sticker (not a box)
    private func addBorder(to image: UIImage, width: Double, color: UIColor) -> UIImage {
        let borderWidth = CGFloat(width)
        let padding = borderWidth + 2 // Extra padding for the border

        let newSize = CGSize(
            width: image.size.width + padding * 2,
            height: image.size.height + padding * 2
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            let ctx = context.cgContext
            let center = CGPoint(x: padding, y: padding)

            // Draw the image multiple times at offsets to create edge-following outline
            // This creates a "stroke" effect around the alpha channel
            let offsets = generateCircularOffsets(radius: borderWidth, steps: max(16, Int(borderWidth * 4)))

            // First pass: draw colored versions at offsets (creates the border)
            for offset in offsets {
                let offsetRect = CGRect(
                    x: center.x + offset.x,
                    y: center.y + offset.y,
                    width: image.size.width,
                    height: image.size.height
                )

                // Draw a colored version of the image (using the alpha as mask)
                drawColoredImage(image, in: offsetRect, color: color, context: ctx)
            }

            // Second pass: draw the original image on top
            let imageRect = CGRect(
                x: center.x,
                y: center.y,
                width: image.size.width,
                height: image.size.height
            )
            image.draw(in: imageRect)
        }
    }

    /// Generates evenly spaced points around a circle
    private func generateCircularOffsets(radius: CGFloat, steps: Int) -> [CGPoint] {
        var offsets: [CGPoint] = []
        for i in 0..<steps {
            let angle = (CGFloat(i) / CGFloat(steps)) * 2 * .pi
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            offsets.append(CGPoint(x: x, y: y))
        }
        return offsets
    }

    /// Draws the image filled with a solid color (preserving alpha)
    private func drawColoredImage(_ image: UIImage, in rect: CGRect, color: UIColor, context: CGContext) {
        guard let cgImage = image.cgImage else { return }

        context.saveGState()

        // Flip for UIKit coordinate system
        context.translateBy(x: rect.origin.x, y: rect.origin.y + rect.height)
        context.scaleBy(x: 1, y: -1)

        // Clip to the image's alpha
        let drawRect = CGRect(origin: .zero, size: rect.size)
        context.clip(to: drawRect, mask: cgImage)

        // Fill with border color
        context.setFillColor(color.cgColor)
        context.fill(drawRect)

        context.restoreGState()
    }

    // MARK: - Border (GPU-Accelerated using CIMorphologyMaximum)

    /// Adds an outline border using GPU-accelerated morphological dilation
    /// This method expands the alpha channel and fills with border color
    private func addBorderGPU(to image: UIImage, width: Double, color: UIColor) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let borderWidth = CGFloat(width)
        let padding = borderWidth + 4

        // Create CIImage from the original
        let ciImage = CIImage(cgImage: cgImage)

        // Step 1: Extract and dilate the alpha channel
        guard let dilatedAlpha = dilateAlphaChannel(ciImage, radius: Float(borderWidth)) else {
            return image
        }

        // Step 2: Create the final composited image
        let newSize = CGSize(
            width: image.size.width + padding * 2,
            height: image.size.height + padding * 2
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            let context = ctx.cgContext

            // Get the dilated alpha as CGImage
            let dilatedExtent = dilatedAlpha.extent
            guard let dilatedCGImage = self.context.createCGImage(dilatedAlpha, from: dilatedExtent) else {
                image.draw(in: CGRect(x: padding, y: padding, width: image.size.width, height: image.size.height))
                return
            }

            // Calculate positioning to center the dilated image
            let offsetX = padding - (dilatedExtent.width - CGFloat(cgImage.width)) / 2
            let offsetY = padding - (dilatedExtent.height - CGFloat(cgImage.height)) / 2

            let dilatedRect = CGRect(
                x: offsetX,
                y: offsetY,
                width: dilatedExtent.width,
                height: dilatedExtent.height
            )

            // Draw the dilated alpha filled with border color
            context.saveGState()

            // Flip coordinate system
            context.translateBy(x: 0, y: newSize.height)
            context.scaleBy(x: 1, y: -1)

            // Clip to dilated alpha and fill with border color
            context.clip(to: dilatedRect, mask: dilatedCGImage)
            context.setFillColor(color.cgColor)
            context.fill(dilatedRect)

            context.restoreGState()

            // Draw the original image on top (centered)
            let imageRect = CGRect(
                x: padding,
                y: padding,
                width: image.size.width,
                height: image.size.height
            )
            image.draw(in: imageRect)
        }
    }

    /// Dilates the alpha channel of an image using CIMorphologyMaximum
    private func dilateAlphaChannel(_ image: CIImage, radius: Float) -> CIImage? {
        // CIMorphologyMaximum dilates (expands) bright areas
        // We apply it to the alpha channel to expand the mask

        // First, extract alpha channel by using CIColorMatrix to zero out RGB
        guard let alphaExtract = CIFilter(name: "CIColorMatrix") else { return nil }
        alphaExtract.setValue(image, forKey: kCIInputImageKey)
        // Set matrix to extract alpha into all channels: R=A, G=A, B=A, A=A
        alphaExtract.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputRVector")
        alphaExtract.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputGVector")
        alphaExtract.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputBVector")
        alphaExtract.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        guard let alphaImage = alphaExtract.outputImage else { return nil }

        // Apply morphological dilation
        guard let morphFilter = CIFilter(name: "CIMorphologyMaximum") else { return nil }
        morphFilter.setValue(alphaImage, forKey: kCIInputImageKey)
        morphFilter.setValue(radius, forKey: kCIInputRadiusKey)

        return morphFilter.outputImage
    }

    // MARK: - Shadow

    private func addShadow(to image: UIImage, opacity: Double) -> UIImage {
        let shadowOffset = CGSize(width: 0, height: 4)
        let shadowRadius: CGFloat = 8
        let shadowColor = UIColor.black.withAlphaComponent(CGFloat(opacity))

        // Calculate new size to accommodate shadow
        let padding = shadowRadius * 2 + abs(shadowOffset.height)
        let newSize = CGSize(
            width: image.size.width + padding * 2,
            height: image.size.height + padding * 2
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            let ctx = context.cgContext

            // Set up shadow
            ctx.setShadow(offset: shadowOffset, blur: shadowRadius, color: shadowColor.cgColor)

            // Draw the image
            let imageRect = CGRect(
                x: padding,
                y: padding,
                width: image.size.width,
                height: image.size.height
            )
            image.draw(in: imageRect)
        }
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: CGFloat
        switch hexSanitized.count {
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
