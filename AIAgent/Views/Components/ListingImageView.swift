import SwiftUI

/// Unified image view for listings — shows imageData first, then imageURL, then emoji fallback
struct ListingImageView: View {
    let listing: Listing
    var height: CGFloat = 120
    var cornerRadius: CGFloat = 10

    var body: some View {
        if let imageData = listing.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else if let imageURL = listing.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                case .failure:
                    emojiFallback
                case .empty:
                    ProgressView()
                        .frame(height: height)
                @unknown default:
                    emojiFallback
                }
            }
        } else {
            emojiFallback
        }
    }

    private var emojiFallback: some View {
        HStack {
            Spacer()
            Text(listing.category.emoji)
                .font(.system(size: height * 0.5))
            Spacer()
        }
        .frame(height: height * 0.7)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Small square version for list rows and preview cards
struct ListingThumbnailView: View {
    let listing: Listing
    var size: CGFloat = 50

    var body: some View {
        if let imageData = listing.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else if let imageURL = listing.imageURL, let url = URL(string: imageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                case .failure:
                    emojiFallback
                case .empty:
                    ProgressView()
                        .frame(width: size, height: size)
                @unknown default:
                    emojiFallback
                }
            }
        } else {
            emojiFallback
        }
    }

    private var emojiFallback: some View {
        Text(listing.category.emoji)
            .font(.system(size: size * 0.6))
            .frame(width: size, height: size)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
