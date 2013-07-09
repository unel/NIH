# return

storage = new A.RS.Storage("jquery", "/rs/test_repo.json");



A.RS.rqDo(storage,
    ['jquery-ui-c', 'naked-ass-c', A.RS.P.FS(1024)]
    ($, imageURL, FS) ->
        $("<div><img src='#{imageURL}'></div>").dialog({width: "auto"})
        # FS.rmDir('/RS'
        #     -> console.log('rm ok')
        #     (fe) -> console.error('rm err', fe)
        # )
)

# A.RS.rqDo(storage,
#     ['naked-ass', 'jquery']
#     (imageURL, $) -> $('<img>', {src: imageURL}).appendTo('body')
# )