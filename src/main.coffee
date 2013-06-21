storage = new A.RS.Storage("jquery"
    "scripts":
        "jquery":     ["/js/jquery-1.9.1.min.js", {"export": ["jQuery"]}],
        "jquery-ui":  ["/js/jquery-ui.js", {
            "export": ["jQuery"],
            "require": ["jquery:jQuery", "jquery-ui-stylesheet"]
        }],
        "underscore": ["/js/underscore.js", {"export": ["_"]}],

    "styles":
        "NIHCSS": "/src/NIH.css",
        "jquery-ui-stylesheet": "/css/jquery-ui-1.10.3.custom.css"

    "images":
        "naked-ass": "/img/nakedass.png",
        "heavy": "/img/33.jpg"
)

storage.addResource(
    new A.RS.Linked(
        "jquery-ui",
        new A.RS.SimpleCache("")
        new A.RS.Script("", "/js/jquery-ui.js")
        {
            "export": ["jQuery"],
            "require": ["jquery:jQuery", "jquery-ui-stylesheet"]
        }
    )
)

storage.addResource(new A.RS.ExternalScript("jquery-e",
                                            "//ajax.googleapis.com/ajax/libs/jquery/1.10.1/jquery.min.js",
                                            {"export": ["jQuery"]}))

storage.addResource(new A.RS.ExternalScript("jquery-ui-e",
                                            "//ajax.googleapis.com/ajax/libs/jqueryui/1.10.3/jquery-ui.min.js",
                                            {
                                                "export": ["jQuery"],
                                                "require": ["jquery-e:jQuery"]
                                            }))
# A.RS.rqDo(storage,
#     ['jquery-ui-e', 'naked-ass']
#     ($, u) ->

#         x = $("<div id='2'><img src='#{u}'></div>")
#         x.dialog({"modal": true})
# )


A.RS.rqDo(storage,
    ['jquery-ui', 'naked-ass']
    ($, imageURL) -> $("<div><img src='#{imageURL}'></div>").dialog({width: "auto"})
)

A.RS.rqDo(storage,
    ['naked-ass', 'jquery']
    (imageURL, $) -> $('<img>', {src: imageURL}).appendTo('body')
)