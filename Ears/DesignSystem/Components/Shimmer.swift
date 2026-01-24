//
//  Shimmer.swift
//  Ears
//
//  Loading skeleton/shimmer effect for placeholder content
//

import SwiftUI

/// A shimmer effect for loading placeholders
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Add a shimmer effect to indicate loading
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Views

/// A placeholder skeleton view for loading states
struct SkeletonView: View {
    let shape: SkeletonShape
    let width: CGFloat?
    let height: CGFloat

    enum SkeletonShape {
        case rectangle
        case roundedRectangle(cornerRadius: CGFloat)
        case circle
        case capsule
    }

    init(_ shape: SkeletonShape = .roundedRectangle(cornerRadius: 8), width: CGFloat? = nil, height: CGFloat = 20) {
        self.shape = shape
        self.width = width
        self.height = height
    }

    var body: some View {
        Group {
            switch shape {
            case .rectangle:
                Rectangle()
                    .fill(Color(.systemGray5))
            case .roundedRectangle(let cornerRadius):
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemGray5))
            case .circle:
                Circle()
                    .fill(Color(.systemGray5))
            case .capsule:
                Capsule()
                    .fill(Color(.systemGray5))
            }
        }
        .frame(width: width, height: height)
        .shimmer()
    }
}

/// Skeleton for a book grid item
struct BookGridItemSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonView(.roundedRectangle(cornerRadius: 8), height: 150)
                .aspectRatio(1, contentMode: .fit)

            SkeletonView(width: 120, height: 16)
            SkeletonView(width: 80, height: 12)
        }
    }
}

/// Skeleton for a book list item
struct BookListItemSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonView(.roundedRectangle(cornerRadius: 6), width: 60, height: 60)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(width: 150, height: 16)
                SkeletonView(width: 100, height: 12)
                SkeletonView(width: 60, height: 10)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        BookGridItemSkeleton()
            .frame(width: 150)

        BookListItemSkeleton()
            .padding()

        HStack(spacing: 16) {
            SkeletonView(.circle, width: 50, height: 50)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(width: 120, height: 16)
                SkeletonView(width: 80, height: 12)
            }
        }
        .padding()
    }
}
