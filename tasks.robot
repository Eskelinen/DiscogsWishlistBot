*** Settings ***
Documentation       Creates a list of the albums for sale on a Discogs wishlist and organises them starting from the cheapest.

Library             RPA.Browser.Selenium
Library             RPA.HTTP
Library             Collections
Library             OperatingSystem
Library             RPA.Email.ImapSmtp    smtp_server=smtp.gmail.com    smtp_port=587
Library             RPA.Robocorp.Vault


*** Variables ***
${ALBUM_LIMIT}      50
${CHECKED}          0


*** Tasks ***
Create a list of the albums for sale on a Discogs wishlist and organise them starting from the cheapest.
    Access credentials
    Open discogs website
    Login
    Accept cookies
    Navigate to wishlist and set album limit
    Get albums and sort
    Send email


*** Keywords ***
# Browser opened straight to the login page
Open discogs website
    Open available browser    https://www.discogs.com/login?return_to=https%3A%2F%2Fwww.discogs.com%2F

# Inputting username and password and logging in

Login
    Input Text    username    ${DISCOGS_USERNAME}
    Input Text    password    ${DISCOGS_PASSWORD}
    Submit Form

# Getting rid of the cookies popup. Need to wait for it to appear first.

Accept cookies
    Wait Until Page Contains Element    id:onetrust-button-group-parent
    Click Button    onetrust-accept-btn-handler

# Setting the album limit to what it was determined to before

Navigate to wishlist and set album limit
    Click Element    class:wantlist-tab-link
    Wait Until Page Contains Element    id:limit_top
    Select From List By Value    id:limit_top    ${ALBUM_LIMIT}

# Full handling of the wishlist

Get albums and sort
    ${ALBUMS}    Create List
    ${rows}    Get Element Count    //*[@id="list"]/table/tbody/tr
    ${TOTAL_ROWS}    Set Variable    ${rows}
    # Loop is rolled until no more albums are to be checked.
    WHILE    ${TOTAL_ROWS}> ${CHECKED}
        ${rows}    Get Element Count    //*[@id="list"]/table/tbody/tr
        FOR    ${index}    IN RANGE    ${rows}
            ${CHECKED}    Evaluate    ${CHECKED} + 1
            ${ARTIST_TITLE}    Get Text    xpath://*[@id="list"]/table/tbody/tr[${index+1}]/td[4]/span[1]/a[1]
            ${ALBUM_TITLE}    Get Text    xpath://*[@id="list"]/table/tbody/tr[${index+1}]/td[4]/span[1]/span[1]/a
            ${PRICE_EXISTS}    Does Page Contain Element
            ...    xpath://*[@id="list"]/table/tbody/tr[${index+1}]/td[4]/span[1]/span[2]/span
            # If an album has no price, it is not contained in the list.
            IF    ${PRICE_EXISTS}== False    CONTINUE
            ${ALBUM_PRICE}    Get Text    xpath://*[@id="list"]/table/tbody/tr[${index+1}]/td[4]/span[1]/span[2]/span
            ${ALBUM}    Create Dictionary
            Set To Dictionary    ${ALBUM}
            ...    Artist=${ARTIST_TITLE}
            ...    Album=${ALBUM_TITLE}
            ...    Price=${ALBUM_PRICE}
            Append To List    ${ALBUMS}    ${ALBUM}
        END
        ${MORE_PAGES}    Does Page Contain Element    class:pagination_next
        # If more pages exist, move to next page. Loop breaks when last page is reached.
        IF    ${MORE_PAGES}== True
            Click Element    class:pagination_next
        ELSE
            BREAK
        END
        # Counting rows to figure out if loop still has to run
        ${rows}    Get Element Count    //*[@id="list"]/table/tbody/tr
        ${TOTAL_ROWS}    Evaluate    ${TOTAL_ROWS} + ${rows}
    END
    ${ALBUMS}    Sort albums by price    ${ALBUMS}
    Save sorted albums to file    ${ALBUMS}

Sort albums by price
    # List is sorted by price from lowest to highest.
    [Arguments]    ${albums}
    ${sorted_albums}    Evaluate    sorted(${albums}, key=lambda x: float(x['Price'].replace('€', '').strip()))
    RETURN    ${sorted_albums}

Save sorted albums to file
    # Sorted list is saved to a .txt file
    [Arguments]    ${albums}
    ${file_path}    Join Path    ${OUTPUT_DIR}    albums_for_sale.txt
    Create File    ${file_path}
    FOR    ${album}    IN    @{albums}
        ${artist}    Set Variable    ${album['Artist']}
        ${album_name}    Set Variable    ${album['Album']}
        ${price}    Set Variable    ${album['Price']}
        ${album_info}    Set Variable    ${artist} - ${album_name} - ${price}
        Append To File    ${file_path}    ${album_info}\n
    END

Send email
    # File is sent to the user's email address.
    Authorize    account=${EMAIL_USERNAME}    password=${EMAIL_PASSWORD}
    Send Message    sender=${EMAIL_USERNAME}
    ...    recipients=${EMAIL_RECIPIENT}
    ...    subject=Discogs wishlist bot results
    ...    body=Here are the results of the Discogs wishlist robot.
    ...    attachments=${OUTPUT_DIR}${/}albums_for_sale.txt

Access credentials
    # Getting credentials from the control room vault.
    ${secret}    Get Secret    wishlistbot
    Set Global Variable    ${DISCOGS_USERNAME}    ${secret}[DISCOGS_USERNAME]
    Set Global Variable    ${DISCOGS_PASSWORD}    ${secret}[DISCOGS_PASSWORD]
    Set Global Variable    ${EMAIL_USERNAME}    ${secret}[EMAIL_USERNAME]
    Set Global Variable    ${EMAIL_PASSWORD}    ${secret}[EMAIL_PASSWORD]
    Set Global Variable    ${EMAIL_RECIPIENT}    ${secret}[EMAIL_RECIPIENT]
