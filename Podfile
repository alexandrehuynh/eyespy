platform :ios, '15.0'

def shared_pods
  pod 'MediaPipeTasksVision'
  pod 'MediaPipeTasksCommon'
end

target 'eyespy' do
  use_frameworks!
  shared_pods

  target 'eyespyTests' do
    inherit! :search_paths
    shared_pods
  end

  target 'eyespyUITests' do
    inherit! :search_paths
    shared_pods
  end
end
