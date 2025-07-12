#if os(macOS)
//
//  SimpleView-macOS.swift
//  Storm
//
//  Minimal RealityKit test view for macOS (macOS 14+ using RealityView).
//

import SwiftUI
import RealityKit

@available(macOS 14.0, *)
struct SimpleView_macOS: View {
    var body: some View {
        ZStack {
            RealityView { content in
                createGameScene(content)
            }.gesture(tapEntityGesture)
            // Add camera controls that orbit the origin.
            .realityViewCameraControls(.tilt)
            //.realityViewCameraControls(.orbit)

            // Add instructions to tap the cube.
            VStack {
                Spacer()
                Text("Tap the cube to spin!")
            }.padding()
        }
    }
    
    /// A gesture that spins entities that have a spin component.
    var tapEntityGesture: some Gesture {
        TapGesture().targetedToAnyEntity()
            .onEnded({ gesture in
                if gesture.entity.components.has(SpinComponent.self) {
                    try? spinEntity(gesture.entity)
                }
            })
    }

    /// Creates a game scene and adds it to the view content.
    ///
    /// - Parameter content: The active content for this RealityKit game.
    fileprivate func createGameScene(_ content: any RealityViewContentProtocol) {
        let boxSize: SIMD3<Float> = [0.2, 0.2, 0.2]
        // A component that shows a red box model.
        let boxModel = ModelComponent(
            mesh: .generateBox(size: boxSize),
            materials: [SimpleMaterial(color: .red, isMetallic: true)]
        )
        // Components that allow interaction and visual feedback.
        let inputTargetComponent = InputTargetComponent()
        let hoverComponent = HoverEffectComponent()

        // A component that sets the collision shape.
        let boxCollision = CollisionComponent(shapes: [.generateBox(size: boxSize)])

        // A component that stores spin information.
        let spinComponent = SpinComponent()

        // Set all the entity's components.
        let boxEntity = Entity()
        boxEntity.components.set([
            boxModel, boxCollision, inputTargetComponent, hoverComponent,
            spinComponent
        ])

        // Add the entity to the RealityView content.
        content.add(boxEntity)

        // Add a perspective camera to the scene.
        let camera = Entity()
        camera.components.set(PerspectiveCameraComponent())
        content.add(camera)

        // Set the camera position and orientation.
        let cameraLocation: SIMD3<Float> = [1, 1, 2]
        camera.look(at: .zero, from: cameraLocation, relativeTo: nil)
    }

    /// Spins an entity around the y-axis.
    /// - Parameter entity: The entity to spin.
    func spinEntity(_ entity: Entity) throws {
        // Get the entity's spin component.
        guard let spinComponent = entity.components[SpinComponent.self] else { return }

        // Create a spin action that makes one revolution
        // around the axis from the component.
        let spinAction = SpinAction(revolutions: 1, localAxis: spinComponent.spinAxis)

        // Create a one second animation that spins an entity.
        let spinAnimation = try AnimationResource.makeActionAnimation(
            for: spinAction,
            duration: 1,
            bindTarget: .transform
        )

        // Play the animation that spins the entity.
        entity.playAnimation(spinAnimation)
    }
}

/// A component that spins the entity around a given axis.
struct SpinComponent: RealityKit.Component {
    let spinAxis: SIMD3<Float> = [0, 1, 0]
}

#endif
