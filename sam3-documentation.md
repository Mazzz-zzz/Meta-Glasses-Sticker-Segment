Home
Explore
fal-ai/sam-3/image

Search...
⌘
k
Docs
Blog
Pricing
Enterprise
$9.82


avatar
Segment Anything Model 3 Image to Image
fal-ai/sam-3/image

Image to Image
SAM 3 is a unified foundation model for promptable segmentation in images and videos. It can detect, segment, and track objects using text or visual prompts such as points, boxes, and masks.
Inference
Commercial use

Schema
LLMs

Table of contents

Swift / iOS
1. Calling the API
Install the client
Setup your API Key
Submit a request
Real-time via WebSockets
2. Authentication
API Key
3. Queue
Submit a request
Fetch request status
Get the result
4. Files
Data URI (base64)
Hosted files (URL)
Uploading files
5. Schema
Input
Output
Other
About
Segment Image

1. Calling the API
#
Install the client
#
The client provides a convenient way to interact with the model API.


.package(url: "https://github.com/fal-ai/fal-swift.git")
The Swift client is distributed through the Swift Package Manager. Cocoapods, Carthage or any other package manager is not supported at the moment. Visit swiftpackageindex.com/fal-ai/fal-swift for more information.

Setup your API Key
#
Set FAL_KEY as an environment variable in your runtime.


export FAL_KEY="YOUR_API_KEY"
Submit a request
#
The client API handles the API submit protocol. It will handle the request status updates and return the result when the request is completed.


import FalClient

let result = try await fal.subscribe(
    to: "fal-ai/sam-3/image",
    input: [
        "image_url": "https://raw.githubusercontent.com/facebookresearch/segment-anything-2/main/notebooks/images/truck.jpg"
    ],
    includeLogs: true
) { update in
    if case let .inProgress(logs) = update {
        print(logs)
    }
}
Real-time via WebSockets
#
This model has a real-time mode via websockets, this is supported via the fal.realtime client.


import FalClient

let connection = try fal.realtime.connect(to: "fal-ai/sam-3/image") { result in
    switch result {
    case let .success(data):
        print(data)
    case let .failure(error):
        print(error)
    }
}

connection.send([
    "image_url": "https://raw.githubusercontent.com/facebookresearch/segment-anything-2/main/notebooks/images/truck.jpg"
])
2. Authentication
#
The API uses an API Key for authentication. It is recommended you set the FAL_KEY environment variable in your runtime when possible.

API Key
#
In case your app is running in an environment where you cannot set environment variables, you can set the API Key manually as a client configuration.

import FalClient

let fal = FalClient.withCredentials(.keyPair("YOUR_FAL_KEY"))
Protect your API Key
When running code on the client-side (e.g. in a browser, mobile app or GUI applications), make sure to not expose your FAL_KEY. Instead, use a server-side proxy to make requests to the API. For more information, check out our server-side integration guide.

3. Queue
#
Long-running requests
For long-running requests, such as training jobs or models with slower inference times, it is recommended to check the Queue status and rely on Webhooks instead of blocking while waiting for the result.

Submit a request
#
The client API provides a convenient way to submit requests to the model.


import FalClient

let job = try await fal.queue.submit(
    "fal-ai/sam-3/image",
    input: [
        "image_url": "https://raw.githubusercontent.com/facebookresearch/segment-anything-2/main/notebooks/images/truck.jpg"
    ],
    webhookUrl: "https://optional.webhook.url/for/results"
)
Fetch request status
#
You can fetch the status of a request to check if it is completed or still in progress.


import FalClient

let status = try await fal.queue.status(
    "fal-ai/sam-3/image",
    of: "764cabcf-b745-4b3e-ae38-1200304cf45b",
    includeLogs: true
)
Get the result
#
Once the request is completed, you can fetch the result. See the Output Schema for the expected result format.


import FalClient

let result = try await fal.queue.response(
    "fal-ai/sam-3/image",
    of: "764cabcf-b745-4b3e-ae38-1200304cf45b"
)
4. Files
#
Some attributes in the API accept file URLs as input. Whenever that's the case you can pass your own URL or a Base64 data URI.

Data URI (base64)
#
You can pass a Base64 data URI as a file input. The API will handle the file decoding for you. Keep in mind that for large files, this alternative although convenient can impact the request performance.

Hosted files (URL)
#
You can also pass your own URLs as long as they are publicly accessible. Be aware that some hosts might block cross-site requests, rate-limit, or consider the request as a bot.

Uploading files
#
We provide a convenient file storage that allows you to upload files and use them in your requests. You can upload files using the client API and use the returned URL in your requests.


import FalClient

let data = try await Data(contentsOf: URL(fileURLWithPath: "/path/to/file"))
let url = try await fal.storage.upload(data)
Auto uploads
The client will auto-upload the file for you if you pass a binary object (e.g. File, Data).

Read more about file handling in our file upload guide.

5. Schema
#
Input
#
image_url string
URL of the image to be segmented

prompt string
Text prompt for segmentation Default value: "wheel"

point_prompts list<PointPrompt>
List of point prompts

box_prompts list<BoxPrompt>
Box prompt coordinates (x_min, y_min, x_max, y_max). Multiple boxes supported - use object_id to group boxes for the same object or leave empty for separate objects.

apply_mask boolean
Apply the mask on the image. Default value: true

sync_mode boolean
If True, the media will be returned as a data URI.

output_format OutputFormatEnum
The format of the generated image. Default value: "png"

Possible enum values: jpeg, png, webp

return_multiple_masks boolean
If True, upload and return multiple generated masks as defined by max_masks.

max_masks integer
Maximum number of masks to return when return_multiple_masks is enabled. Default value: 3

include_scores boolean
Whether to include mask confidence scores.

include_boxes boolean
Whether to include bounding boxes for each mask (when available).


{
  "image_url": "https://raw.githubusercontent.com/facebookresearch/segment-anything-2/main/notebooks/images/truck.jpg",
  "prompt": "wheel",
  "point_prompts": [],
  "box_prompts": [],
  "apply_mask": true,
  "output_format": "png",
  "max_masks": 3
}
Output
#
image Image
Primary segmented mask preview.

masks list<Image>
Segmented mask images.

metadata list<MaskMetadata>
Per-mask metadata including scores and boxes.

scores list<float>
Per-mask confidence scores when requested.

boxes list<list<float>>
Per-mask normalized bounding boxes [cx, cy, w, h] when requested.


{
  "masks": [
    {
      "url": "",
      "content_type": "image/png",
      "file_name": "z9RV14K95DvU.png",
      "file_size": 4404019,
      "width": 1024,
      "height": 1024
    }
  ],
  "metadata": [
    {}
  ]
}
Other types
#
BoxPrompt
#
x_min integer
X Min Coordinate of the box

y_min integer
Y Min Coordinate of the box

x_max integer
X Max Coordinate of the box

y_max integer
Y Max Coordinate of the box

object_id integer
Optional object identifier. Boxes sharing an object id refine the same object.

frame_index integer
The frame index to interact with.

SAM3DObjectMetadata
#
object_index integer
Index of the object in the scene

scale list<list<float>>
Scale factors [sx, sy, sz]

rotation list<list<float>>
Rotation quaternion [x, y, z, w]

translation list<list<float>>
Translation [tx, ty, tz]

camera_pose list<list<float>>
Camera pose matrix

PointPromptBase
#
x integer
X Coordinate of the prompt

y integer
Y Coordinate of the prompt

label LabelEnum
1 for foreground, 0 for background

Possible enum values: 0, 1

object_id integer
Optional object identifier. Prompts sharing an object id refine the same object.

File
#
url string
The URL where the file can be downloaded from.

content_type string
The mime type of the file.

file_name string
The name of the file. It will be auto-generated if not provided.

file_size integer
The size of the file in bytes.

file_data string
File data

Image
#
url string
The URL where the file can be downloaded from.

content_type string
The mime type of the file.

file_name string
The name of the file. It will be auto-generated if not provided.

file_size integer
The size of the file in bytes.

file_data string
File data

width integer
The width of the image in pixels.

height integer
The height of the image in pixels.

BoxPromptBase
#
x_min integer
X Min Coordinate of the box

y_min integer
Y Min Coordinate of the box

x_max integer
X Max Coordinate of the box

y_max integer
Y Max Coordinate of the box

object_id integer
Optional object identifier. Boxes sharing an object id refine the same object.

SAM3DBodyMetadata
#
num_people integer
Number of people detected

people list<SAM3DBodyPersonMetadata>
Per-person metadata

MaskMetadata
#
index integer
Index of the mask inside the model output.

score float
Score for this mask.

box list<float>
Bounding box for the mask in normalized cxcywh coordinates.

PointPrompt
#
x integer
X Coordinate of the prompt

y integer
Y Coordinate of the prompt

label LabelEnum
1 for foreground, 0 for background

Possible enum values: 0, 1

object_id integer
Optional object identifier. Prompts sharing an object id refine the same object.

frame_index integer
The frame index to interact with.

SAM3DBodyPersonMetadata
#
person_id integer
Index of the person in the scene

bbox list<float>
Bounding box [x_min, y_min, x_max, y_max]

focal_length float
Estimated focal length

pred_cam_t list<float>
Predicted camera translation [tx, ty, tz]

keypoints_2d list<list<float>>
2D keypoints [[x, y], ...] - 70 body keypoints

keypoints_3d list<list<float>>
3D keypoints [[x, y, z], ...] - 70 body keypoints in camera space

SAM3DBodyAlignmentInfo
#
person_id integer
Index of the person

scale_factor float
Scale factor applied for alignment

translation list<float>
Translation [tx, ty, tz]

focal_length float
Focal length used

target_points_count integer
Number of target points for alignment

cropped_vertices_count integer
Number of cropped vertices

Related Models
Learn More
Status
Documentation
Pricing
Enterprise
Grants
Learn
About Us
Careers
Blog
Get in touch
Models
AuraFlow
Flux.1 [schnell]
Flux.1 [dev]
Flux Realism LoRA
Flux LoRA
Explore More
Playgrounds
Training
Workflows
Demos
Socials
Discord
GitHub
Reddit
Twitter
Linkedin
features and labels, 2025. All Rights Reserved. Terms of Service and Privacy Policy
