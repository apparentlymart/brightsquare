
var dataForm = document.getElementById("dataform");

function setValue(key, value) {
    dataForm.elements[key].value = value;
}

function submit() {
    dataForm.submit();
}

