QUnit.module('data-remote', {
  beforeEach: function() {
    $('#qunit-fixture')
      .append($('<a />', {
        href: '/echo',
        'data-remote': 'true',
        'data-params': 'data1=value1&data2=value2',
        text: 'my address'
      }))
      .append($('<button />', {
        'data-url': '/echo',
        'data-remote': 'true',
        'data-params': 'data1=value1&data2=value2',
        text: 'my button'
      }))
      .append($('<form />', {
        action: '/echo',
        'data-remote': 'true',
        method: 'post',
        id: 'my-remote-form'
      }))
      .append($('<a />', {
        href: '/echo',
        'data-remote': 'true',
        disabled: 'disabled',
        text: 'Disabed link'
      }))
      .find('form').append($('<input type="text" name="user_name" value="john">'))

  }
})

QUnit.test('ctrl-clicking on a link does not fire ajaxyness', function(assert) {
  var done = assert.async();

  var link = $('a[data-remote]')

  // Ideally, we'd setup an iframe to intercept normal link clicks
  // and add a test to make sure the iframe:loaded event is triggered.
  // However, jquery doesn't actually cause a native `click` event and
  // follow links using `trigger('click')`, it only fires bindings.
  link
    .removeAttr('data-params')
    .bindNative('ajax:beforeSend', function() {
      assert.ok(false, 'ajax should not be triggered')
    })

  link.triggerNative('click', { metaKey: true })
  link.triggerNative('click', { ctrlKey: true })

  assert.ok(true, 'ajax should not be triggered')

  setTimeout(function() { done() }, 13)
})

QUnit.test('ctrl-clicking on a link still fires ajax for non-GET links and for links with "data-params"', function(assert) {
  var done = assert.async();

  var link = $('a[data-remote]')

  link
    .removeAttr('data-params')
    .attr('data-method', 'POST')
    .bindNative('ajax:beforeSend', function() {
      assert.ok(true, 'ajax should be triggered')
    })
    .triggerNative('click', { metaKey: true })

  link
    .removeAttr('data-method')
    .attr('data-params', 'name=steve')
    .triggerNative('click', { metaKey: true })

  setTimeout(function() { done() }, 13)
})

QUnit.test('clicking on a link with data-remote attribute', function(assert) {
  var done = assert.async();

  $('a[data-remote]')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked(assert, 'ajax:success')
      App.assertRequestPath(assert, data, '/echo')
      assert.equal(data.params.data1, 'value1', 'ajax arguments should have key data1 with right value')
      assert.equal(data.params.data2, 'value2', 'ajax arguments should have key data2 with right value')
      App.assertGetRequest(assert, data)
    })
    .bindNative('ajax:complete', function() { done() })
    .triggerNative('click')
})

QUnit.test('clicking on a link with both query string in href and data-params', function(assert) {
  var done = assert.async();

  $('a[data-remote]')
    .attr('href', '/echo?data3=value3')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertGetRequest(assert, data)
      assert.equal(data.params.data1, 'value1', 'ajax arguments should have key data1 with right value')
      assert.equal(data.params.data2, 'value2', 'ajax arguments should have key data2 with right value')
      assert.equal(data.params.data3, 'value3', 'query string in url should be passed to server with right value')
    })
    .bindNative('ajax:complete', function() { done() })
    .triggerNative('click')
})

QUnit.test('clicking on a link with both query string in href and data-params with POST method', function(assert) {
  var done = assert.async();

  $('a[data-remote]')
    .attr('href', '/echo?data3=value3')
    .attr('data-method', 'post')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertPostRequest(assert, data)
      assert.equal(data.params.data1, 'value1', 'ajax arguments should have key data1 with right value')
      assert.equal(data.params.data2, 'value2', 'ajax arguments should have key data2 with right value')
      assert.equal(data.params.data3, 'value3', 'query string in url should be passed to server with right value')
    })
    .bindNative('ajax:complete', function() { done() })
    .triggerNative('click')
})

//QUnit.test('clicking on a link with disabled attribute', function(assert) {
  //var done = assert.async();

  //$('#qunit-fixture a[disabled]')
  //.bindNative('ajax:before', function(e, data, status, xhr) {
    //App.assertCallbackNotInvoked(assert, 'ajax:success')
  //})
  //.bindNative('ajax:complete', function() { done() })
  //.triggerNative('click')

  //setTimeout(function() {
    //done()
  //}, 13)
//})

QUnit.test('clicking on a button with data-remote attribute', function(assert) {
  var done = assert.async();

  $('button[data-remote]')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked(assert, 'ajax:success')
      App.assertRequestPath(assert, data, '/echo')
      assert.equal(data.params.data1, 'value1', 'ajax arguments should have key data1 with right value')
      assert.equal(data.params.data2, 'value2', 'ajax arguments should have key data2 with right value')
      App.assertGetRequest(assert, data)
    })
    .bindNative('ajax:complete', function() { done() })
    .triggerNative('click')
})

QUnit.test('changing a select option with data-remote attribute', function(assert) {
  var done = assert.async();

  $('form')
    .append(
      $('<select />', {
        'name': 'user_data',
        'data-remote': 'true',
        'data-params': 'data1=value1',
        'data-url': '/echo'
      })
      .append($('<option />', {value: 'optionValue1', text: 'option1'}))
      .append($('<option />', {value: 'optionValue2', text: 'option2'}))
    )

  $('select[data-remote]')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked(assert, 'ajax:success')
      App.assertRequestPath(assert, data, '/echo')
      assert.equal(data.params.user_data, 'optionValue2', 'ajax arguments should have key term with right value')
      assert.equal(data.params.data1, 'value1', 'ajax arguments should have key data1 with right value')
      App.assertGetRequest(assert, data)
    })
    .bindNative('ajax:complete', function() { done() })
    .val('optionValue2')
    .triggerNative('change')
})

QUnit.test('submitting form with data-remote attribute', function(assert) {
  var done = assert.async();

  $('form[data-remote]')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked(assert, 'ajax:success')
      App.assertRequestPath(assert, data, '/echo')
      assert.equal(data.params.user_name, 'john', 'ajax arguments should have key user_name with right value')
      App.assertPostRequest(assert, data)
    })
    .bindNative('ajax:complete', function() { done() })
    .triggerNative('submit')
})

QUnit.test('submitting form with data-remote attribute should include inputs in a fieldset only once', function(assert) {
  var done = assert.async();

  $('form[data-remote]')
    .append('<fieldset><input name="items[]" value="Item" /></fieldset>')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked(assert, 'ajax:success')
      assert.equal(data.params.items.length, 1, 'ajax arguments should only have the item once')
      App.assertPostRequest(assert, data)
    })
    .bindNative('ajax:complete', function() {
      $('form[data-remote], fieldset').remove()
      done()
    })
    .triggerNative('submit')
})

QUnit.test('submitting form with data-remote attribute submits input with matching [form] attribute', function(assert) {
  var done = assert.async();

  $('#qunit-fixture')
    .append($('<input type="text" name="user_data" value="value1" form="my-remote-form">'))

  $('form[data-remote]')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked(assert, 'ajax:success')
      App.assertRequestPath(assert, data, '/echo')
      assert.equal(data.params.user_name, 'john', 'ajax arguments should have key user_name with right value')
      assert.equal(data.params.user_data, 'value1', 'ajax arguments should have key user_data with right value')
      App.assertPostRequest(assert, data)
    })
    .bindNative('ajax:complete', function() { done() })
    .triggerNative('submit')
})

QUnit.test('submitting form with data-remote attribute by clicking button with matching [form] attribute', function(assert) {
  var done = assert.async();

  $('#qunit-fixture form[data-remote]')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked(assert, 'ajax:success')
      App.assertRequestPath(assert, data, '/echo')
      assert.equal(data.params.user_name, 'john', 'ajax arguments should have key user_name with right value')
      assert.equal(data.params.user_data, 'value2', 'ajax arguments should have key user_data with right value')
      App.assertPostRequest(assert, data)
    })
    .bindNative('ajax:complete', function() { done() })

  $('<button />', {
        type: 'submit',
        name: 'user_data',
        value: 'value1',
        form: 'my-remote-form'
      })
    .appendTo($('#qunit-fixture'))

  $('<button />', {
      type: 'submit',
      name: 'user_data',
      value: 'value2',
      form: 'my-remote-form'
    })
    .appendTo($('#qunit-fixture'))
    .triggerNative('click')
})

QUnit.test('form\'s submit bindings in browsers that don\'t support submit bubbling', function(assert) {
  var done = assert.async();

  var form = $('#qunit-fixture form[data-remote]'), directBindingCalled = false

  assert.ok(!directBindingCalled, 'nothing is called')

  form
    .append($('<input type="submit" />'))
    .bindNative('submit', function(event) {
      assert.ok(event.type == 'submit', 'submit event handlers are called with submit event')
      assert.ok(true, 'binding handler is called')
      directBindingCalled = true
    })
    .bindNative('ajax:beforeSend', function() {
      assert.ok(true, 'form being submitted via ajax')
      assert.ok(directBindingCalled, 'binding handler already called')
    })
    .bindNative('ajax:complete', function() {
      done()
    })

    if(!$.support.submitBubbles) {
      // Must indrectly submit form via click to trigger jQuery's manual submit bubbling in IE
      form.find('input[type=submit]')
      .triggerNative('click')
    } else {
      form.triggerNative('submit')
    }
})

QUnit.test('returning false in form\'s submit bindings in non-submit-bubbling browsers', function(assert) {
  var done = assert.async();

  var form = $('form[data-remote]')

  form
    .append($('<input type="submit" />'))
    .bindNative('submit', function() {
      assert.ok(true, 'binding handler is called')
      return false
    })
    .bindNative('ajax:beforeSend', function() {
      assert.ok(false, 'form should not be submitted')
    })

    if (!$.support.submitBubbles) {
      // Must indrectly submit form via click to trigger jQuery's manual submit bubbling in IE
      form.find('input[type=submit]').triggerNative('click')
    } else {
      form.triggerNative('submit')
    }

    setTimeout(function() { done() }, 13)
})

QUnit.test('clicking on a link with falsy "data-remote" attribute does not fire ajaxyness', function(assert) {
  var done = assert.async();

  $('a[data-remote]')
    .attr('data-remote', 'false')
    .bindNative('ajax:beforeSend', function() {
      assert.ok(false, 'ajax should not be triggered')
    })
    .bindNative('click', function() {
      return false
    })
    .triggerNative('click')

  assert.ok(true, 'ajax should not be triggered');

  setTimeout(function() { done() }, 20)
})

QUnit.test('ctrl-clicking on a link with falsy "data-remote" attribute does not fire ajaxyness even if "data-params" present', function(assert) {
  var done = assert.async();

  var link = $('a[data-remote]')

  link
    .removeAttr('data-params')
    .attr('data-remote', 'false')
    .attr('data-method', 'POST')
    .bindNative('ajax:beforeSend', function() {
      assert.ok(false, 'ajax should not be triggered')
    })
    .bindNative('click', function() {
      return false
    })
    .triggerNative('click', { metaKey: true })

  link
    .removeAttr('data-method')
    .attr('data-params', 'name=steve')
    .triggerNative('click', { metaKey: true })

  assert.ok(true, 'ajax should not be triggered');

  setTimeout(function() { done() }, 20)
})

QUnit.test('clicking on a button with falsy "data-remote" attribute', function(assert) {
  var done = assert.async();

  $('button[data-remote]:first')
    .attr('data-remote', 'false')
    .bindNative('ajax:beforeSend', function() {
      assert.ok(false, 'ajax should not be triggered')
    })
    .bindNative('click', function() {
      return false
    })
    .triggerNative('click')

  assert.ok(true, 'ajax should not be triggered');

  setTimeout(function() { done() }, 20)
})

QUnit.test('submitting a form with falsy "data-remote" attribute', function(assert) {
  var done = assert.async();

  $('form[data-remote]:first')
    .attr('data-remote', 'false')
    .bindNative('ajax:beforeSend', function() {
      assert.ok(false, 'ajax should not be triggered')
    })
    .bindNative('submit', function() {
      return false
    })
    .triggerNative('submit')

  assert.ok(true, 'ajax should not be triggered');

  setTimeout(function() { done() }, 20)
})

QUnit.test('changing a select option with falsy "data-remote" attribute', function(assert) {
  var done = assert.async();

  $('#qunit-fixture form')
    .append(
      $('<select />', {
        'name': 'user_data',
        'data-remote': 'false',
        'data-params': 'data1=value1',
        'data-url': '/echo'
      })
      .append($('<option />', {value: 'optionValue1', text: 'option1'}))
      .append($('<option />', {value: 'optionValue2', text: 'option2'}))
    )

  $('select[data-remote=false]:first')
    .bindNative('ajax:beforeSend', function() {
      assert.ok(false, 'ajax should not be triggered')
    })
    .val('optionValue2')
    .triggerNative('change')

  assert.ok(true, 'ajax should not be triggered');

  setTimeout(function() { done() }, 20)
})

QUnit.test('form should be serialized correctly', function(assert) {
  var done = assert.async();

  $('#qunit-fixture form')
    .append('<textarea name="textarea">textarea</textarea>')
    .append('<input type="checkbox" name="checkbox[]" value="0" />')
    .append('<input type="checkbox" checked="checked" name="checkbox[]" value="1" />')
    .append('<input type="radio" checked="checked" name="radio" value="0" />')
    .append('<input type="radio" name="radio" value="1" />')
    .append('<select multiple="multiple" name="select[]">\
      <option value="1" selected>1</option>\
      <option value="2" selected>2</option>\
      <option value="3">3</option>\
      <option selected>4</option>\
    </select>')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      assert.equal(data.params.checkbox.length, 1)
      assert.equal(data.params.checkbox[0], '1')
      assert.equal(data.params.radio, '0')
      assert.equal(data.params.select.length, 3)
      assert.equal(data.params.select[2], '4')
      assert.equal(data.params.textarea, 'textarea')

      done()
    })
    .triggerNative('submit')
})

QUnit.test('form buttons should only be serialized when clicked', function(assert) {
  var done = assert.async();

  $('#qunit-fixture form')
    .append('<input type="submit" name="submit1" value="submit1" />')
    .append('<button name="submit2" value="submit2" />')
    .append('<button name="submit3" value="submit3" />')
    .bindNative('ajax:success', function(e, data, status, xhr) {
      assert.equal(data.params.submit1, undefined)
      assert.equal(data.params.submit2, 'submit2')
      assert.equal(data.params.submit3, undefined)
      assert.equal(data['rack.request.form_vars'], 'user_name=john&submit2=submit2')

      done()
    })
    .find('[name=submit2]').triggerNative('click')
})
