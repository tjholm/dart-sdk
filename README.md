<p align="center">
  <a href="https://nitric.io">
    <img src="assets/nitric-logo.svg" width="120" alt="Nitric Logo"/>
  </a>
</p>

<p align="center">
  Build <a href="https://nitric.io">Nitric</a> applications with Dart
</p>

<p align="center">
  <a href="https://nitric.io/chat"><img alt="Discord" src="https://img.shields.io/discord/955259353043173427?label=discord&style=for-the-badge"></a>
</p>

The Dart SDK supports the use of the Nitric framework with Dart and Flutter. For more information, check out the main [Nitric repo](https://github.com/nitrictech/nitric).

Nitric SDKs provide an infrastructure-as-code style that lets you define resources in code. You can also write the functions that support the logic behind APIs, subscribers and schedules.

You can request the type of access you need to resources such as publishing for topics, without dealing directly with IAM or policy documents.

## Status

The SDK is in early stage development and APIs and interfaces are still subject to breaking changes. We’d love your feedback as we build additional functionality!

## Get in touch:

- Ask questions in [GitHub discussions](https://github.com/nitrictech/nitric/discussions)

- Join us on [Discord](https://nitric.io/chat)

- Find us on [Twitter](https://twitter.com/nitric_io)

- Send us an [email](mailto:maintainers@nitric.io)

# Building a REST API with Nitric

This guide will show you how to build a serverless REST API with the Nitric framework using Dart. The example API enables reading, writing and editing basic user profile information using a Nitric [collection](https://nitric.io/docs/collections) to store user data. Once the API is created we'll test it locally, then optionally deploy it to a cloud of your choice.

The example API enables reading, writing, and deleting profile information from a Nitric [collection](https://nitric.io/docs/collection).

The API will provide the following routes:

| **Method** | **Route**      | **Description**                        |
| ---------- | -------------- | -------------------------------------- |
| `GET`      | /profiles/[id] | Get a specific profile image by its id |
| `GET`      | /profiles      | List all profiles                      |
| `POST`     | /profiles      | Create a new profile image             |
| `DELETE`   | /profiles/[id] | Delete a profile                       |

There is also an extended section of the guide that adds file operations using a Nitric [bucket](https://nitric.io/docs/storage) to store and retrieve profile pictures using signed URLs. The extension adds these routes to the API:

| **Method** | **Route**                     | **Description**                   |
| ---------- | ----------------------------- | --------------------------------- |
| `GET`      | /profiles/[id]/image/upload   | Get a profile image upload URL    |
| `GET`      | /profiles/[id]/image/download | Get a profile image download URL  |
| `GET`      | /profiles/[id]/image/view     | View the image that is downloaded |

## Prerequisites

- [Dart](https://dart.dev/get-dart)
- The [Nitric CLI](/guides/getting-started/installation)
- An [AWS](https://aws.amazon.com), [Google Cloud](https://cloud.google.com) or [Azure](https://azure.microsoft.com) account (_your choice_)

## Getting started

Start by creating a base Dart

```bash
dart create -t console my-profile-api
```

Add the Nitric SDK by adding the repository URL to your `pubspec.yaml`.

```yaml
nitric_sdk:
  git:
    url: https://github.com/nitrictech/dart-sdk.git
    ref: main
```

Next, open the project in your editor of choice.

```bash
cd my-profile-api
```

The scaffolded project should have the following structure:

```text
bin/
├── my_profile_api.dart
lib/
├── my_profile_api.dart
test/
├── my_profile_api_test.dart
.gitignore
analysis_options.yaml
CHANGELOG.md
pubspec.lock
pubspec.yaml
README.md
```

To create our Nitric project, we have to create a `nitric.yaml` file. The handlers key will point to where our

```yaml
name: my_profile_api
services:
  - match: bin/my_profile_api.dart
    start: dart run bin/my_profile_api.dart
```

## Create a Profile class

We will create a class to represent the profiles that we will store in the collection. We will add `toJson` and `fromJson` functions to assist.

```dart
class Profile {
  String name;
  int age;
  String homeTown;

  Profile(this.name, this.age, this.homeTown);

  Profile.fromJson(Map<String, dynamic> contents)
      : name = contents["name"] as String,
        age = contents["age"] as int,
        homeTown = contents["homeTown"] as String;

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'homeTown': homeTown,
      };
}

```

## Building the API

Applications built with Nitric can contain many APIs, let's start by adding one to this project to serve as the public endpoint. Rename `bin/my_profile_api.dart` to `bin/profiles.dart`

```dart
import 'package:uuid/uuid.dart';

import 'package:nitric_sdk/src/api/collection.dart';
import 'package:nitric_sdk/src/nitric.dart';
import 'package:nitric_sdk/src/resources/common.dart';

void main() {
  // Create an API named 'public'
  final profileApi = api("public");

  // Define a collection named 'profiles', then request reading and writing permissions.
  final profiles = collection<Profile>("profiles").requires([
    CollectionPermission.writing,
    CollectionPermission.deleting,
    CollectionPermission.reading
  ]);
}
```

Here we're creating an API named `public` and a collection named `profiles`, then requesting read, write, and delete permissions which allows our function to access the collection.

<Note>
  Resources in Nitric like `api` and `collection` represent high-level cloud
  resources. When your app is deployed Nitric automatically converts these
  requests into appropriate resources for the specific
  [provider](https://nitric.io/docs/reference/providers). Nitric also takes care of adding the IAM
  roles, policies, etc. that grant the requested access. For example the
  `collection` resource uses DynamoDB in AWS or FireStore on Google Cloud.
</Note>

### Create profiles with POST

Let's start adding features that allow our API consumers to work with profile data.

<Note>
  You could separate some or all of these handlers into their own files if you
  prefer. For simplicity we'll group them together in this guide.
</Note>

```dart
profileApi.post("/profiles", (ctx) async {
  final uuid = Uuid();

  final id = uuid.v4();

  final profile = Profile.fromJson(ctx.req.json());

  // Store the new profile in the profiles collection
  await profiles.key(id).put(profile);

  // Send a success response.
  ctx.resp.body = "Profile $id created.";

  return ctx;
});
```

### Retrieve a profile with GET

```dart
profileApi.get("/profiles/:id", (ctx) async {
  final id = ctx.req.pathParams["id"]!;

  try {
    // Retrieve and return the profile data
    final profile = await profiles.key(id).access();
    ctx.resp.json(profile.toJson());
  } on KeyNotFoundException catch (e) {
    print(e);
    ctx.resp.status = 404;
    ctx.resp.body = "Profile $id not found.";
  }

  return ctx;
});
```

### List all profiles with GET

```dart
profileApi.get("/profiles", (ctx) async {
  // Return all profiles
  final allProfiles = await profiles.list();

  ctx.resp.json({'profiles': allProfiles});

  return ctx;
});
```

### Remove a profile with DELETE

```dart
profileApi.delete("/profiles/:id", (ctx) async {
  final id = ctx.req.pathParams["id"]!;

  // Delete the profile
  try {
    await profiles.key(id).unset();
    ctx.resp.body = "Profile $id removed.";
  } on KeyNotFoundException catch (e) {
    ctx.resp.status = 404;
    ctx.resp.body = "Profile $id not found.";
  }

  return ctx;
});
```

## Ok, let's run this thing!

Now that you have an API defined with handlers for each of its methods, it's time to test it locally.

```bash
npm run dev
```

<Note>
  the `dev` script starts the Nitric Server using `nitric start`, which provides
  local interfaces to emulate cloud resources, then runs your functions and
  allows them to connect.
</Note>

Once it starts, the application will receive requests via the API port. You can use the Local Dashboard or any HTTP client to test the API. We'll keep it running for our tests. If you want to update your functions, just save them, they'll be reloaded automatically.

## Test the API

Below are some example requests you can use to test the API. You'll need to update all values in brackets `[]` and change the URL to your deployed URL if you're testing on the cloud.

### Create Profile

```bash
curl --location --request POST 'http://localhost:4001/profiles' \
--header 'Content-Type: text/plain' \
--data-raw '{
    "name": "Peter Parker",
    "age": "21",
    "homeTown" : "Queens"
}'
```

### Fetch Profile

```bash
curl --location --request GET 'http://localhost:4001/profiles/[id]'
```

### Fetch All Profiles

```bash
curl --location --request GET 'http://localhost:4001/profiles'
```

### Delete Profile

```bash
curl --location --request DELETE 'http://localhost:4001/profiles/[id]'
```

## Deploy to the cloud

At this point, you can deploy the application to any supported cloud provider. Start by setting up your credentials and any configuration for the cloud you prefer:

- [AWS](/reference/providers/aws)
- [Azure](/reference/providers/azure)
- [Google Cloud](/reference/providers/gcp)

Next, we'll need to create a `stack`. Stacks represent deployed instances of an application, including the target provider and other details such as the deployment region. You'll usually define separate stacks for each environment such as development, testing and production. For now, let's start by creating a `dev` stack.

```bash
nitric stack new
```

```
? What should we name this stack? dev
? Which provider do you want to deploy with? aws
? Which region should the stack deploy to? us-east-1
```

### AWS

<Note>
  Cloud deployments incur costs and while most of these resource are available
  with free tier pricing you should consider the costs of the deployment.
</Note>

In the previous step we called our stack `dev`, let's try deploying it with the `up` command.

```bash
nitric up
┌───────────────────────────────────────────────────────────────┐
| API  | Endpoint                                               |
| main | https://XXXXXXXX.execute-api.us-east-1.amazonaws.com   |
└───────────────────────────────────────────────────────────────┘
```

When the deployment is complete, go to the relevant cloud console and you'll be able to see and interact with your API. If you'd like to make changes to the API you can apply those changes by rerunning the `up` command. Nitric will automatically detect what's changed and just update the relevant cloud resources.

When you're done testing your application you can tear it down from the cloud, use the `down` command:

```bash
nitric down
```

## Optional - Add profile image upload/download support

If you want to go a bit deeper and create some other resources with Nitric, why not add images to your profiles API.

### Access profile buckets with permissions

Define a bucket named `profilesImg` with reading/writing permissions.

```dart
final profilesImg = bucket("profilesImg").requires([BucketPermission.reading, BucketPermission.writing]);
```

### Get a URL to upload a profile image

```dart
profileApi.get("/profiles/:id/image/upload", (ctx) async {
  final id = ctx.req.pathParams["id"];

  // Return a signed upload URL, which provides temporary access to upload a file.
  final photoUrl = await profilesImg.file("images/$id/photo.png").getUploadUrl();

  ctx.req.body = photoUrl;

  return ctx;
});
```

### Get a URL to download a profile image

```dart
profileApi.get("/profiles/:id/image/download", (ctx) async {
  final id = ctx.req.pathParams["id"];

  // Return a signed download URL, which provides temporary access to download a file.
  final photoUrl = await profilesImg.file("images/$id/photo.png").getDownloadUrl();

  ctx.req.body = photoUrl;

  return ctx;
});
```

You can also return a redirect response that takes the HTTP client directly to the photo URL.

```dart
profileApi.get("/profiles/:id/image/view", (ctx) async {
  final id = ctx.req.pathParams["id"];

  // Redirect to a signed read-only file URL.
  final photoUrl = await profilesImg.file("images/$id/photo.png").getDownloadUrl();

  ctx.resp.status = 303;
  ctx.resp.headers["Location"] = [photoUrl];

  return ctx;
});
```

#### Test the extended API

Update all values in brackets `[]` and change the URL to your deployed URL if you're testing on the cloud.

#### Get an image upload URL

```bash
curl --location --request GET 'http://localhost:4001/profiles/[id]/image/upload'
```

#### Using the upload URL with curl

```bash
curl --location --request PUT '[url]' \
--header 'content-type: image/png' \
--data-binary '@/home/user/Pictures/photo.png'

```

#### Get an image download URL

```bash
curl --location --request GET 'http://localhost:4001/profiles/[id]/image/download'
```
