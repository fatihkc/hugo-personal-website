function handler(event) {
    var request = event.request;
    var uri = request.uri;
    var host = request.headers.host.value;
    
    // Redirect www to non-www (canonical URL)
    if (host.startsWith('www.')) {
        var canonicalHost = host.substring(4); // Remove 'www.' prefix
        return {
            statusCode: 301,
            statusDescription: 'Moved Permanently',
            headers: {
                'location': {
                    value: 'https://' + canonicalHost + uri
                }
            }
        };
    }
    
    // Check whether the URI is missing a file name.
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    } 
    // Check whether the URI is missing a file extension.
    else if (!uri.includes('.')) {
        request.uri += '/index.html';
    }

    return request;
}