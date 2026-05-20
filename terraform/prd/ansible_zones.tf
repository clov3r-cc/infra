resource "ansible_group" "dmz" {
  name = "dmz"
}

resource "ansible_group" "internal" {
  name = "internal"
}
