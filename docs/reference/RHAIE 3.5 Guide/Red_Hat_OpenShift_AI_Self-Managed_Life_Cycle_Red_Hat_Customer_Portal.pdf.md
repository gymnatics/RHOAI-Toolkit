# Red Hat OpenShift AI Self-Managed Life Cycle _ Red Hat Customer Portal.pdf

# Red Hat OpenShift AI Self-Managed Life Cycle

### Contents

Overview 

Life Cycle Phases 

Life Cycle Dates 

Historic Version List 

Release Types 

Upgrade Policy 

Upgrade Strategy and Paths 

Early Access 

GA/Stable and GA-x.y 

Extended Update Support eus-x.y 

Migrating from 2.x to 3.x 

## Overview

### Red Hat provides a published Product Life Cycle for Red Hat OpenShift AI (RHOAI) Self-

### Managed in order for customers and partners to effectively plan, deploy, and support their

### infrastructure and applications running on the platform. Red Hat publishes this life cycle in an

### effort to provide as much transparency as possible and may make exceptions from these policies

### as conflicts may arise. Customers are expected to upgrade Red Hat OpenShift AI (RHOAI) to the

### most current supported version of the product in a timely fashion. Bug fixes and features are

### targeted for the latest versions of the product (Full Support Phase), See below for more

### information on Production Phases.

### Red Hat OpenShift AI Self-Managed is available as an Operator to Red Hat OpenShift and

### maintains a release schedule that is independent from other Red Hat products and services.

### The Red Hat OpenShift Life Cycle provides information on supported versions for Red Hat

Subscriptions Downloads Red Hat Console Get Support 

Red Hat OpenShift AI Self-Managed Life CycleSupport Life Cycle & Update Policies 

## Life Cycle Phases

### Full support

### Full Support is provided according to the published Scope of Coverage and Service Level

### Agreement. Likewise, Development Support is provided according to the published Scope of

### Coverage and Service Level Agreement. During the Full Support Phase, qualified Critical,

### Important, and Moderate CVEs with a CVSS score of 7.0 or higher as defined by Red Hat in a Red

### Hat Security Advisory (RHSA) and Urgent and Selected High Priority Bug Fix advisories (RHBAs)

### will be released as they become available; all other available fix and qualified patches may be

### released via periodic updates. In order to receive security and bug fixes, customers are expected

### to upgrade their Red Hat OpenShift AI environment to the most current supported micro (3.x.z)

### version.

### Maintenance Support

### During the Maintenance Support phase, qualified Critical and Important Security Advisories

### (RHSAs) will be released as they become available. Urgent and Selected High Priority Bug Fix

### Advisories (RHBAs) may be released as they become available. Other Bug Fix (and Enhancement

### (RHEA) Advisories may be released at Red Hat’s discretion, but should not be expected.

### Extended Support

### During the Extended Update Support phase Red Hat will maintain component specific support.

### For supported components in a given release, including any component-level EUS exceptions,

### please refer to the Supported Configurations page.

### Component-level EUS exceptions

### During the Extended Update Support phase, Red Hat maintains component-specific support.

### Certain components may be supported only through the Full Support phase of an EUS release

### and are excluded from Extended Update Support.

### Components with a shortened support window are identified on the Supported Configurations

### page, including the date when support for that component ends. After that date, the component

### is End of Life (EOL) and is no longer supported, even if the overall release remains in Extended

### Update Support.

### Red Hat communicates component-level EUS exceptions in advance through the Supported

### Configurations page and release notes.

### Note: From April 2025, CVEs with a CVSS score of 7 and higher are being reported and fixed.

## Life Cycle Dates

Full Support 

Version: 

3.5 

Tier: Agnostic 

OpenShift Compatibility: 4.22, 4.21, 4.20, 4.19 

Release Type: GA, EUS 

Available in Channel(s): stable-3.x, stable-3.5, eus-3.5 

General availability: 

Aug 27, 2026 

Full support: 

Aug 27, 2026 

to 

Mar 29, 2027 

Extended update support: 

Mar 30, 2027 

to 

Feb 28, 2028 

Version: 

3.4 

Tier: Agnostic 

OpenShift Compatibility: 4.21, 4.20, 4.19 

Release Type: GA 

Available in Channel(s): stable-3.x, stable-3.4 

General availability: 

May 14, 2026 

Full support: 

May 14, 2026 

to 

Nov 16, 2026 

Extended update support: 

### The former names of this product are: Red Hat OpenShift Data Science self-managed

### [*] The 2.11 support phase has been extended as an exception. During the extended support

### phase, Red Hat will provide technical support and critical security updates only.

Version: 

3.3 

Tier: Agnostic 

OpenShift Compatibility: 4.21, 4.20, 4.19 

Release Type: stable 

Available in Channel(s): stable-3.x, stable-3.3 

General availability: 

Mar 5, 2026 

Full support: 

Mar 5, 2026 

to 

Oct 5, 2026 

Extended update support: 

N/A 

Version: 

2.25 

Tier: Agnostic 

OpenShift Compatibility: 4.21, 4.20, 4.19, 4.18, 4.17, 4.16 

Release Type: stable, EUS 

Available in Channel(s): stable, stable-2.25, eus-2.25 

General availability: 

Oct 23, 2025 

Full support: 

Oct 23, 2025 

to 

May 25, 2026 

Extended update support: 

May 26, 2026 

to 

Apr 26, 2027 

## Historic Version List

### Versions of Red Hat OpenShift AI Self-Managed that are out of support or have reached end of

### life are listed on the Red Hat Customer Portal Product Life Cycles page. This page provides full

### Life Cycle dates for all releases, including end of Full Support and end of Extended Update

### Support dates.

### For the complete historic version list, see Red Hat OpenShift AI Self-Managed — Product Life

### Cycles

## Release Types

### RHOAI release types, and their respective Life Cycles, generally fall under three main categories:

### Early Access releases: These releases do not have support and last for one month, or

### until the next release is available. They are designed to test new features.

### GA releases: These releases include Full Support for seven months. Red Hat issues a GA

### release every two Early Access releases. 3.4.EA1 => 3.4.EA2 => 3.4GA

### Extended Update Support (EUS) releases: These releases include Full Support for

### seven months followed by Extended Update Support for eleven months. Red Hat issues an

### EUS release every three GA releases.

### Upgrade Policy

### The RHOAI operator and installed components are automatically updated to the latest version,

### unless the manual upgrade strategy is opted for. For more information about how to install the

### operator and configure the update strategy, see the RHOAI Documentation. Customers are

### advised to deploy the latest available minor version at their earliest convenience.

### Upgrade Strategy and Paths

### Customers are advised to choose their upgrade strategy according to their needs, which might

### vary in terms of release longevity or number of features available. When defining this strategy, it

### is important to consider that choosing the automatic approach ensures that customers will

### receive all the latest security and bug fixes for the currently supported version. Red Hat

### *OpenShift AI uses major (x.), minor (x.y), and micro (x.y.z) release versions and maintains a *

### release schedule that is independent from other Red Hat products and services. Red Hat tests

### and supports upgrade paths that are allowed according to the OLM rules enforced by the

### operator. The customer is free to change the streaming channels accordingly.

### at all times. You must be on the latest available version in your selected channel to receive

### support for Red Hat OpenShift AI.

### *Early Access (EA) *

### Customers who want to try upcoming product features before a specific version is made

### Generally Available can now do so by deploying Early Access versions. For example, before

### version 3.5 of OpenShift AI is officially released, Red Hat will make 2 EA versions available to

### customers. They would be labelled 3.5-EA1 and 3.5-EA2. They would be released roughly 1 and 2

### months before the GA version of 3.5 is available. Be advised that Red Hat does not provide

### support for EA versions, including security updates and CVE fixes. These deployments are

### recommended only where early access to new features is desirable and production support is not

### required. Red Hat recommends choosing this streaming channel with the automatic update

### strategy to receive EA drops as they are published. For Early Access releases, they are provided in

### the beta update channels. Important: Upgrades are not supported for EA versions. Deploying an

### EA drop or moving from an EA drop to a GA release will require a fresh installation. Red Hat only

### supports upgrades across GA versions. For example:

### *3.4.0 (GA) -> 3.5.0 (GA) *

### *GA/Stable and GA-x.y *

### Starting with 3.x customers who prioritize stability over new feature availability are recommended

### *to choose the ga, ga-3.x or ga-x.y streaming channels. Selecting the automatic updates strategy *

### with the GA, unnumbered channel, will result in the deployments being upgraded to the latest GA

### minor version as soon as it is released. This choice will reduce the overhead of manually updating

### as soon as a new GA release is available and will grant access to the latest GA features.

### Alternatively, selecting the numbered GA channels will allow customers to plan and execute the

### upgrade to the next GA release while keeping their deployment under full support within a four-

### month time window. Be advised that Red Hat supports from two to three GA releases at a given

### time. These types of deployments are recommended for most stage and production

### *environments. In the ga and ga-x.y update channels, Red Hat supports single-step upgrades from *

### the most recent previous minor GA version to the latest minor GA version. For example, users

### *could upgrade from OpenShift AI 3.4.0 (ga) as follows: *

### *3.4.0 (GA) -> 3.4.1 (GA) *

### *3.4.1 (GA) -> 3.5.0 (GA) *

### *3.5.0 (GA) -> 3.5.1 (GA) *

### 3.4.0 (GA) -> 3.4.1 (GA) 3.4.1 (GA) -> 3.5.0 (GA) 3.5.0 (GA) -> 3.5.1 (GA)

### *eus-x.y *

### *For customers prioritizing stability, the eus-x.y streaming channels offer up to nine months for *

### planning upgrades to the next Extended Update Support (EUS) release. These channels suit

### enterprise environments needing extended support beyond a seven-month upgrade cycle. Red

### Hat supports single-step upgrades between consecutive minor EUS versions. This dual approach

### enables seamless transitions, accommodating both stability and access to newer releases.

### Red Hat tests and supports upgrade paths that are allowed according to the OLM rules enforced

### by the operator. The customer is free to change the streaming channels accordingly.

## Migrating from 2.x to 3.x

### The OpenShift AI 3.0 release introduces significant technology and component changes, making

### a direct upgrade from 2.25 technically complex. OpenShift AI 2.25 is a stable and EUS release

### and will continue to be supported for an extended period per the defined life cycle.

### You can upgrade from OpenShift AI 2.25.4 to 3.3 (latest). Use the following guidance when

### upgrading or migrating from your respective Red Hat OpenShift AI version:

### New Installations: To perform a new installation of Red Hat OpenShift AI 3.3, install the

### Red Hat OpenShift AI on a cluster running OpenShift Container Platform 4.19 (latest z-

### *stream release) or later and select the stable-3.x channel. *

### Upgrading from 3.2: Upgrades from OpenShift AI 3.2 to 3.3 are fully supported. Note:

### OpenShift AI 3.3 is the last release under the fast channel, we recommend you to switch

### *from fast to stable-3.x after the upgrade. *

### Migrating from 2.x: OpenShift AI 3.3 (latest) is the first 3.x release to support migration

### from OpenShift AI 2.25.4 (and later). For instructions on how to plan your migration, see

### Assess and plan for migration from OpenShift AI 2.25.4 (and later) to 3.3 (latest).

### For more information, see the Upgrade from OpenShift AI 2.25.4 (and later) to OpenShift AI 3.3

### (latest) Knowledgebase article.

## Products:

## Category:

Red Hat OpenShift AI 

Supportability 

All systems operational 

About Red Hat 

Jobs 

Events 

Locations 

Contact Red Hat 

Red Hat Blog 

Inclusion at Red Hat 

Cool Stuff Store 

Red Hat Summit 

© 2026 Red Hat 

Privacy statement 

Terms of use 

All policies and guidelines 

Digital accessibility 

Cookie preferences 

### Quick Links

### Help

### Site Info

### Related Sites