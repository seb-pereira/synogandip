# synogandip [![Build Status](https://app.travis-ci.com/seb-pereira/synogandip.svg?token=zDyyH6AHSGrN9gGrdzaP&branch=main)](https://app.travis-ci.com/seb-pereira/synogandip)

_A simple tool to easily update a DNS record hosted by the registrar Gandi.net with your public IP_

***

If you answer **yes** to these questions you might be interested by this tool:

1. Is your domain registered on gandi.net?

2. Does your public IP address assigned by your internet provider change over time (i.e., a dynamic IP)?

3. Do you host services you want available over Internet using your domain name?

If you own a Synology NAS here is an additional reason: the tool can be easily scheduled on your NAS **without requiring additional dependency*** such as Python, Docker or any other package (tested with DSM 7). This use case is addressed in section "[Configuring on your Synology NAS](#configuring-synogandip-on-your-synology-nas)".

## Getting started

This tools is composed of two files: a configuration file (`synogandip.conf`) and a bash script (`synogandip.sh`). The script requires `curl` and `jq`.

1. Download and unzip: https://github.com/seb-pereira/synogandip/releases

2. Edit the configuration file `synogandip.conf`
  - `gandi.api.key` => your gandi.net API key
  - `domain.name` => your domain name. Example: _example.org_
  - `domain.record` => set the name of the sub-domain record to update. Example: to update record for _mysite.example.org_, set _`domain.record=mysite`_

3. Run
  ```
  usage: synogandip.sh [options]
    -f | --file <path>  path to a configuration file. Default: synogandip.conf located in same folder.
    -v                  enable verbose mode: displays remote call responses and additional information.
    -d                  enable dry run mode: record is not created or updated. This option force the verbose mode.
    --version           display the version.
  ```

## How it works?

The tool calls [gandi.net APIs](https://api.gandi.net/docs/) to manage the DNS record of the sub-domain you want to reference your public IP. That is why you must set the configuration property `gandi.api.key` to your [gandi.net API key](https://api.gandi.net/docs/authentication).

- Step 1 - determines your public IP address

  - By default it relies on https://ifconfig.me.
  - You can set the configuration property `public.ip.resolver` to use another service.

- Step 2 - retrieves your sub-domain record 

  - The DNS record is identified using the configuration properties `domain.name` and `domain.record`. For example, if you want _mysite.example.org_ to reference to your public IP, you set _domain.name=example.org_ and _domain.record=mysite_.

- Step 3 - this last step depends on the situation:

  - If the record does not exist, the tool creates a A record with your public IP and a default TTL to 1800. You can set the configuration property `domain.ttl` to customize the TTL to use when the record is created.
  - If the record exist but it does not reference your current IP: the tool updates the record with the current IP.

<!--

For your first run, set the dry-run option `-d` to prevent the tool to create or update the record - even if the DNS record does not exist or if the IP address does not match your actual IP adress. This option enable the verbose mode: 

```
synogandip.sh -d
```

Example of outputs:

<details>
  <summary>when the DNS record does not exist</summary>

```
-------------------------------------------------------------------
 synogandip 1.0
 update gandi.net DNS record with your public IP
-------------------------------------------------------------------
[2022-06-02-19:04:52][INFO] loading configuration /test/synogandip.conf ...
gandi.api.key ............ ********* 
gandi.api.url ............ https://dns.api.gandi.net/api/v5 (default)
domain.name .............. example.org 
domain.record ............ mysite 
domain.ttl ............... 1800 (default)
public.ip.resolver ....... https://ifconfig.me (default)
[2022-06-02-19:04:52][INFO] determining public IP ...
[2022-06-02-19:04:52][VERBOSE] https://ifconfig.me
[2022-06-02-19:04:52][INFO] [example.org] retrieving domain information ...
[2022-06-02-19:04:52][VERBOSE] [example.org] https://dns.api.gandi.net/api/v5/domains/example.org
// ... domain information
[2022-06-02-19:04:52][VERBOSE] [example.org] retrieving zone records information ...
// ... domain records information
[2022-06-02-19:04:52][VERBOSE] [example.org] https://dns.api.gandi.net/api/v5/zones/d94db2ba-cecc-11ec-adb7-00163e816020/records
[2022-06-02-19:04:53][INFO] [mysite.example.org] record does not exist.
[2022-06-02-19:04:53][VERBOSE] [mysite.example.org] updating record with ip [212.194.107.192] (ttl=1800)...
[2022-06-02-19:04:53][VERBOSE] https://dns.api.gandi.net/api/v5/zones/<UUID>/records/mysite/A
[2022-06-02-19:04:53][VERBOSE] >>>>> DRY RUN option -d is enabled: record is NOT updated <<<<<<
[2022-06-02-19:04:53][INFO] [mysite.example.org] record successfully created.
[2022-06-02-19:04:53][INFO] [mysite.example.org] operation completed.>>> DRY RUN MODE <<<
```

</details>

<details>
  <summary>when the DNS record does not match your current public IP</summary>

```
-------------------------------------------------------------------
 synogandip 1.0
 update gandi.net DNS record with your public IP
-------------------------------------------------------------------
[2022-06-02-19:09:39][INFO] loading configuration /test/synogandip.conf ...
gandi.api.key ............ ********* 
gandi.api.url ............ https://dns.api.gandi.net/api/v5 (default)
domain.name .............. example.org 
domain.record ............ mysite 
domain.ttl ............... 1800 (default)
public.ip.resolver ....... https://ifconfig.me (default)
[2022-06-02-19:09:39][INFO] determining public IP ...
[2022-06-02-19:09:39][VERBOSE] https://ifconfig.me
[2022-06-02-19:09:39][INFO] [example.org] retrieving domain information ...
[2022-06-02-19:09:39][VERBOSE] [example.org] https://dns.api.gandi.net/api/v5/domains/example.org
// ... domain information
[2022-06-02-19:09:40][VERBOSE] [example.org] retrieving zone records information ...
[2022-06-02-19:09:40][VERBOSE] [example.org] https://dns.api.gandi.net/api/v5/zones/d94db2ba-cecc-11ec-adb7-00163e816020/records
[2022-06-02-19:09:40][VERBOSE] record found:
// ... mysite.example.org record information
[2022-06-02-18:37:54][VERBOSE] [xxx.xxx.xxx.xxx] => public ip
[2022-06-02-18:37:54][VERBOSE] [yyy.yyy.yyy.yyy] => record ip [mysite.example.org]
[2022-06-02-19:09:40][VERBOSE] [mysite.example.org] record must be updated.
[2022-06-02-19:09:40][VERBOSE] [mysite.example.org] updating record with ip [212.194.107.192] (ttl=10800)...
[2022-06-02-19:09:40][VERBOSE] https://dns.api.gandi.net/api/v5/zones/<UUID>/records/mysite/A
[2022-06-02-19:09:40][VERBOSE] >>>>> DRY RUN option -d is enabled: record is NOT updated <<<<<<
[2022-06-02-19:09:40][INFO] [mysite.example.org] record successfully updated.
[2022-06-02-19:09:40][INFO] [mysite.example.org] operation completed.>>> DRY RUN MODE <<<
```

</details>

<details>
  <summary>when the DNS record reference your current public IP</summary>

```
-------------------------------------------------------------------
 synogandip 1.0
 update gandi.net DNS record with your public IP
-------------------------------------------------------------------
[2022-06-02-18:37:53][INFO] loading configuration /test/synogandip.conf ...
gandi.api.key ............ ********* 
gandi.api.url ............ https://dns.api.gandi.net/api/v5 (default)
domain.name .............. example.org 
domain.record ............ mysite 
domain.ttl ............... 1800 (default)
public.ip.resolver ....... https://ifconfig.me (default)
[2022-06-02-18:37:53][INFO] determining public IP ...
[2022-06-02-18:37:53][VERBOSE] https://ifconfig.me
[2022-06-02-18:37:53][INFO] [example.org] retrieving domain information ...
[2022-06-02-18:37:53][VERBOSE] [example.org] https://dns.api.gandi.net/api/v5/domains/example.org
// ... domain information
[2022-06-02-18:37:54][VERBOSE] [example.org] retrieving zone records information ...
[2022-06-02-18:37:54][VERBOSE] [example.org] https://dns.api.gandi.net/api/v5/zones/<UUID>/records
// ... domain records information
[2022-06-02-18:37:54][VERBOSE] record found:
// ... mysite.example.org record information
[2022-06-02-18:37:54][VERBOSE] [xxx.xxx.xxx.xxx] => public ip
[2022-06-02-18:37:54][VERBOSE] [xxx.xxx.xxx.xxx] => record ip [mysite.example.org]
[2022-06-02-18:37:54][INFO] [mysite.example.org] no change required.
[2022-06-02-18:37:54][INFO] [mysite.example.org] operation completed.>>> DRY RUN MODE <<<
```

</details>

-->

## Configuring on your Synology NAS

You use the DSM Scheduler to run `synogandip.sh` regularely so your DNS record matches your public IP address. You must copy `synogandip.sh` and its configuration file on your NAS, and then you create a Scheduler task. I choosed a non-admin user account to run the Schedule task.

#### 1. Install files

With **File Station**,
  - create a new folder in the user home. Example: `/homes/<user>/ddns`
  - copy both files in it

The configuration file contains an API key which is a sensitive information that must be protected from unauthorized access. Only administrators and the dedicated user should have read access to the configuration file. Update `/homes/<user>/ddns` folder properties:
  - 1/ select the **Permissions** tab
  - 2/ check **Apply to this folder, sub-folders and files**
  - 3/ select **Advanced options** and select `Exclude inherited permissions`
  - 4/ allow Administrators: select **Create**:
    - **user or group**: `administrator`
    - **Permission**: check `Administration`
    - click **Done** and select yes to the information message.
  - 5/ allow read access to `<user>`: select **Create**:
    - **user or group**: select the home user
    - **Permission**: check `Read`
    - click **Done**.
  - 6/ select the **General** tab and copy the **Location**, you will need it in later (should be similar to `/volume1/homes/<user>/ddns`)

#### 2. Create a scheduler task

In **Control Panel**, select the **Task Scheduler**
  - create a new task: select **Create > Scheduled Task > User-defined script**
  - **General** tab
    - Name your task. Example `DDNS mysite.example.org`
    - Select the user who owns the home folder
  - **Schedule** tab
    - choose when you want to run the script. It depends on the frequency your IP address is likely to change.
  - **Task settings** tab
    - **Notification**: I recommend to activate the option **Send run details by email** so you have a report, and you can identified when the IP actually changes.
    -  **Run command**: set the user defined script to `bash <location>/synogandip.sh`, where you replace `<location>` (see step 1 point 6)
  - select **Ok** to create the task.

#### 3. Test

You can temporarely activate **Task Scheduler > Settings: save output results** to get a report written in a file when the task ends.

Run your task and check the result. If you enabled the email notification you should also receive an email.

Once you are satified you may enable the scheduling and disable the save output result setting to prevent report files to accumulate over time.

## Known limitations

- AAAA record update (IPv6) is not supported

***
Developed with :heart: on :earth_africa: