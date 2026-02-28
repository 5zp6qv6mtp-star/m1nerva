var form = document.createElement('form');
var input = document.createElement('input');

input.name = 'filter';
input.id = 'search';
input.placeholder = 'Type here to search this directory';

form.addEventListener('submit', function (e) {
    e.preventDefault();

    var query = input.value.trim();
    if (!query) return;

    var regexStr = "(^|.*[^\\pL])" + query.split(/\s+/).join("([^\\pL]|[^\\pL].*[^\\pL])") + ".*$";
    var regex = RegExp(regexStr, "i");

    listItems.forEach(function(item) {
        item.removeAttribute('hidden');
    });

    listItems.filter(function(item) {
        var text = item.querySelector('td').textContent.replace(/\s+/g, " ");
        return !regex.test(text);
    }).forEach(function(item) {
        item.hidden = true;
    });
});

form.appendChild(input);
document.querySelector('h1').after(form);

var listItems = [].slice.call(document.querySelectorAll('#list tbody tr'));

input.addEventListener('keydown', function(e) {
    if (e.key === "Enter") {
        e.preventDefault();
        if (form.requestSubmit) {
            form.requestSubmit();
        } else {
            form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
        }
    }
});
